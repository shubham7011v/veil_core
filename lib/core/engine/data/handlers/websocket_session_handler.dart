import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/handlers/game_session_handler.dart';
import '../../domain/handlers/voice_session_handler.dart';
import '../../domain/models/session_state.dart';
import '../../domain/models/session_enums.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/participant.dart';
import '../../domain/models/game_move.dart';
import '../../../config/app_config.dart';
import '../../../../features/auth/domain/models/user_stats.dart';
import '../../../../features/social/domain/models/friend_record.dart';
import '../../domain/models/room_event.dart';
import '../../../../features/challenges/domain/models/daily_challenge.dart';
import '../../../../features/voice/data/voice_audio_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/constants/sound_assets.dart';
import '../../../../core/services/audio/audio_service_interface.dart';
import '../../../../core/error/failure.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WebSocketSessionHandler extends GameSessionHandler
    with WidgetsBindingObserver
    implements VoiceSessionHandler {
  WebSocketChannel? _channel;

  final _stateController = StreamController<SessionState>.broadcast();
  final _eventController = StreamController<SessionEventType>.broadcast();
  final _statsController = StreamController<UserStats>.broadcast();
  final _leaderboardController = StreamController<List<UserStats>>.broadcast();
  final _friendsController = StreamController<List<FriendRecord>>.broadcast();
  final _roomEventController = StreamController<RoomEvent>.broadcast();
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _challengesController =
      StreamController<List<DailyChallenge>>.broadcast();
  final _challengeClaimResultController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Failure>.broadcast();

  // Connection state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  // bool _isDisposed was removed to support Singleton reuse.

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _baseReconnectDelay = Duration(seconds: 2);
  String? _lastUrl;
  String? _fcmToken;

  // Managed connection artifacts
  StreamSubscription? _subscription;
  Completer<void>? _connectionCompleter;
  int _connectionId = 0;

  // Message Queue for non-critical requests during reconnection
  final List<Map<String, dynamic>> _messageQueue = [];

  // Connection lock to prevent duplicate simultaneous connections
  bool _isConnecting = false;

  // ✅ FIX #4: Prevent duplicate matchmaking joins
  bool _isJoiningMatchmaking = false;

  int _nextSequence = 1;

  // Heartbeat & Watchdog
  Timer? _heartbeatTimer;
  DateTime _lastMessageTime = DateTime.now();
  static const _heartbeatInterval = Duration(seconds: 10);
  // ✅ FIX #7: Reduced watchdog timeout to 12s for faster failure detection on mobile
  static const _watchdogTimeout = Duration(seconds: 12);

  // Auth timeout
  Timer? _authTimeoutTimer;
  static const _authTimeout = Duration(seconds: 10);

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastMessageTime = DateTime.now();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_connectionStatus == ConnectionStatus.disconnected) {
        timer.cancel();
        return;
      }

      // ✅ FIX #4: Send Heartbeat if connected OR reconnecting (server might still be there)
      // Check for non-null channel to prevent errors
      if (_channel != null) {
        // Safe send without forcing status check, rely on try-catch in _send if needed
        // But for PING, we want to skip the "status connected" check in _send
        try {
          _channel!.sink.add(
            jsonEncode({'type': 'PING', 'seq': _nextSequence++}),
          );
        } catch (e) {
          debugPrint('⚠️ Heartbeat send failed: $e');
        }
      }

      // 2. Watchdog: check if we've heard from server recently
      final idleTime = DateTime.now().difference(_lastMessageTime);

      // ✅ FIX #9: Auto-extend timeout if we are roaming/switching networks (simple heuristic)
      var currentTimeout = _watchdogTimeout;
      if (_connectionStatus == ConnectionStatus.reconnecting) {
        currentTimeout = const Duration(
          seconds: 20,
        ); // Give more time during reconnect
      }

      if (idleTime > currentTimeout) {
        debugPrint(
          '! Watchdog: No server activity for ${idleTime.inSeconds}s (Limit: ${currentTimeout.inSeconds}s). Reconnecting...',
        );
        // Stop heartbeat BEFORE closing to prevent send-after-close errors
        timer.cancel();
        _heartbeatTimer = null;

        // Only trigger failure if we aren't already failed/disconnected
        if (_connectionStatus != ConnectionStatus.disconnected) {
          _updateConnectionStatus(ConnectionStatus.reconnecting);
          // ✅ FIX: Use 1001 (Going Away) instead of reserved 1006
          try {
            _channel?.sink.close(1001, 'Watchdog timeout');
          } catch (_) {}
          _channel = null;
          // Reconnection will be handled by _channel.stream.onDone -> _handleConnectionFailure
        }
      }
    });
  }

  void setFcmToken(String token) {
    _fcmToken = token;
    // If connected, update server immediately
    if (_connectionStatus == ConnectionStatus.connected) {
      _send({
        'type': 'UPDATE_FCM',
        'data': {'token': token},
      });
    }
  }

  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  ConnectionStatus get connectionStatus => _connectionStatus;

  // Voice Callbacks & Managers
  Function(Map<String, dynamic> data)? _voiceCallback;

  @override
  void setVoiceCallback(Function(Map<String, dynamic> data)? callback) =>
      _voiceCallback = callback;

  // Optional Voice Audio Manager for WebRTC (dynamic to avoid direct dependency cycle if strict)
  // Or ideally VoiceAudioManager interface.
  VoiceAudioManager? _voiceManager;

  @override
  void setVoiceManager(dynamic manager) {
    if (manager is VoiceAudioManager) {
      _voiceManager = manager;
    }
  }

  SessionState _currentState = SessionState.initial();

  // Cache for interface properties
  String? _activeEventActorId;
  UnitRank? _lastRankClaimed;
  int _lastCountClaimed = 0;
  final List<String> _gameLog = [];
  String? _lastBluffWinnerId;
  String? _lastBluffLoserId;
  bool? _isBluffSuccessful;
  GameMove? _lastMove;
  bool _isRevealingBluff = false;
  final Map<String, String> _pNames = {};
  String? _lastProcessedEventId;

  WebSocketSessionHandler() {
    _currentState = SessionState.initial();
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App backgrounded - close connection gracefully
        if (_connectionStatus == ConnectionStatus.connected) {
          debugPrint('📱 App backgrounded, disconnecting WebSocket');

          // ✅ FIX: Cancel all timers to prevent memory leak and battery drain
          _heartbeatTimer?.cancel();
          _heartbeatTimer = null;
          _authTimeoutTimer?.cancel();
          _authTimeoutTimer = null;
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          _reconnectScheduleTimer?.cancel();
          _reconnectScheduleTimer = null;

          _channel?.sink.close(1000, 'App backgrounded');
          _updateConnectionStatus(ConnectionStatus.disconnected);
        }
        break;

      case AppLifecycleState.resumed:
        // App foregrounded - attempt reconnection with delay
        debugPrint('📱 App resumed, scheduling connection check');
        _scheduleReconnectIfNeeded();
        break;

      case AppLifecycleState.detached:
        // App being terminated
        dispose();
        break;

      default:
        break;
    }
  }

  /// Schedule reconnection with delay to handle edge cases
  /// This ensures the app is fully resumed and Firebase Auth is ready
  Timer? _reconnectScheduleTimer;

  Future<void> _scheduleReconnectIfNeeded() async {
    // Cancel any existing scheduled reconnect
    _reconnectScheduleTimer?.cancel();

    // Wait a bit to allow the app to fully resume and Firebase to be ready
    _reconnectScheduleTimer = Timer(
      const Duration(milliseconds: 300),
      () async {
        try {
          if (_connectionStatus != ConnectionStatus.connected &&
              _connectionStatus != ConnectionStatus.connecting) {
            debugPrint('🔄 Scheduled reconnection triggered');
            await _attemptAutoReconnect();
          } else {
            debugPrint('⚠️ Reconnect skipped: Already connected or connecting');
          }
        } catch (e) {
          debugPrint('❌ Scheduled reconnect error: $e');
        }
      },
    );
  }

  /// Force reconnection attempt (e.g., from notification handler)
  /// This is a public method that can be called externally
  Future<void> forceReconnect() async {
    debugPrint('🔄 Force reconnect requested');
    if (_connectionStatus == ConnectionStatus.connected) {
      debugPrint('⚠️ Already connected, skipping force reconnect');
      return;
    }
    return _attemptAutoReconnect();
  }

  Future<void> _attemptAutoReconnect() async {
    // Don't auto-reconnect if we are already connected or connecting
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting ||
        _isConnecting) {
      debugPrint('⚠️ Auto-reconnect skipped: Already connected/connecting');
      return;
    }

    try {
      final user = sl.authRepository.currentUser;
      if (user == null) {
        debugPrint('❌ No user found for auto-reconnect');
        return;
      }

      // ✅ FIX: Force token refresh to avoid expired tokens
      final token = await user.getIdToken(true); // Force refresh
      final displayName = user.displayName;

      if (token != null && _lastUrl != null) {
        debugPrint('🔄 Auto-reconnecting with fresh token...');
        // Reset attempts to 0 for a fresh start on resume
        _reconnectAttempts = 0;
        await connect(_lastUrl!, token, displayName: displayName);
      }
    } catch (e) {
      debugPrint('❌ Auto-reconnect failed: $e');
      // If token refresh fails, user needs to re-authenticate
      if (!_errorController.isClosed) {
        _errorController.add(
          const AuthFailure('Session expired. Please sign in again.'),
        );
      }
    }
  }

  // Cached Data
  UserStats? _lastStats;
  List<FriendRecord> _friends = [];

  UserStats? get lastStats => _lastStats;
  List<FriendRecord> get currentFriends => _friends;

  @override
  Stream<SessionState> get sessionStateStream => _stateController.stream;

  @override
  Stream<SessionEventType> get eventStream => _eventController.stream;

  @override
  Stream<Failure> get errorStream => _errorController.stream;

  @override
  SessionState get currentState => _currentState;

  Stream<UserStats> get statsStream => _statsController.stream;

  Stream<List<UserStats>> get leaderboardStream =>
      _leaderboardController.stream;

  Stream<List<FriendRecord>> get friendsStream => _friendsController.stream;

  Stream<RoomEvent> get roomEventStream => _roomEventController.stream;

  Stream<List<DailyChallenge>> get challengesStream =>
      _challengesController.stream;

  Stream<Map<String, dynamic>> get challengeClaimResultStream =>
      _challengeClaimResultController.stream;

  @override
  Stream<Map<String, dynamic>> get chatStream => _chatController.stream;

  @override
  String? get activeEventActorId => _activeEventActorId;

  final Map<String, bool> _typingStatus = {};
  @override
  Map<String, bool> get typingStatus => Map.unmodifiable(_typingStatus);

  @override
  UnitRank? get lastRankClaimed => _lastRankClaimed;

  @override
  int get lastCountClaimed => _lastCountClaimed;

  @override
  List<String> get gameLog => _gameLog;

  @override
  String? get lastBluffWinnerId => _lastBluffWinnerId;

  @override
  String? get lastBluffLoserId => _lastBluffLoserId;

  @override
  bool? get isBluffSuccessful => _isBluffSuccessful;

  @override
  GameMove? get lastMove => _lastMove;

  @override
  bool get isRevealingBluff => _isRevealingBluff;

  @override
  Map<String, String> get pNames => _pNames;

  /// Connect to WebSocket server
  Future<void> connect(
    String serverUrl,
    String firebaseToken, {
    String? displayName,
  }) async {
    _lastUrl = serverUrl;

    if (_connectionStatus == ConnectionStatus.connected) return;

    // If already connecting, wait for the existing completer
    if (_isConnecting &&
        _connectionCompleter != null &&
        !_connectionCompleter!.isCompleted) {
      debugPrint('⌛ Waiting for existing connection attempt...');
      return _connectionCompleter!.future;
    }

    // Reset attempt counter for new explicit connection
    _reconnectAttempts = 0;

    _connectionCompleter = Completer<void>();
    // Start attempt without awaiting it here, we await the completer instead
    _attemptConnection(firebaseToken, displayName: displayName);

    return _connectionCompleter!.future;
  }

  Future<void> _attemptConnection(
    String firebaseToken, {
    String? displayName,
  }) async {
    // ✅ FIX: Connection mutex to prevent duplicate attempts
    if (_isConnecting) {
      debugPrint(
        '⚠️ Connection already in progress, skipping duplicate attempt',
      );
      return;
    }

    if (_connectionStatus == ConnectionStatus.connected) return;

    _isConnecting = true; // Lock
    _connectionId++; // Increment connection instance identity
    final currentId = _connectionId;

    _updateConnectionStatus(
      _reconnectAttempts > 0
          ? ConnectionStatus.reconnecting
          : ConnectionStatus.connecting,
    );

    try {
      try {
        // Stop current heartbeat before changing channel
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;

        // Close existing channel safely
        if (_channel != null) {
          try {
            await _channel?.sink.close();
          } catch (_) {}
          _channel = null;
        }

        debugPrint('Connecting to WebSocket (ID: $currentId): $_lastUrl');
        _channel = WebSocketChannel.connect(Uri.parse(_lastUrl!));

        // ✅ FIX: Wait for handshake before sending AUTH
        // Use a shorter timeout for the handshake itself
        await _channel!.ready.timeout(const Duration(seconds: 8));

        // If we were interrupted by a newer connection, stop here
        if (currentId != _connectionId) {
          debugPrint(
            '🚫 Connection ID $currentId superseded by $_connectionId',
          );
          return;
        }

        debugPrint(
          '✅ WebSocket Handshake Ready (ID: $currentId) - Sending AUTH',
        );

        _setupMessageListener(firebaseToken, displayName: displayName);
        _setupAuth(firebaseToken, displayName: displayName);
      } catch (e) {
        if (currentId != _connectionId) return;
        debugPrint('🚨 Connection Error (ID: $currentId): $e');
        _handleConnectionFailure(firebaseToken, displayName: displayName);
      }
    } finally {
      // Small delay before releasing lock to prevent immediate flapping
      Future.delayed(const Duration(milliseconds: 100), () {
        if (currentId == _connectionId) {
          _isConnecting = false;
        }
      });
    }
  }

  void _setupAuth(String firebaseToken, {String? displayName}) {
    // ✅ FIX #12: Cancel any existing auth timeout first
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = Timer(_authTimeout, () {
      if (_connectionStatus != ConnectionStatus.connected) {
        debugPrint('❌ AUTH_OK timeout - no response from server');
        // Check if channel is still open before closing
        if (_channel != null) {
          _channel?.sink.close(1008, 'Auth timeout');
        }
        _handleConnectionFailure(firebaseToken, displayName: displayName);
      }
    });

    final photoURL = sl.authRepository.currentUser?.photoURL;
    _send({
      'type': 'AUTH',
      'data': {
        'token': firebaseToken,
        'name': displayName ?? 'Player',
        'avatar_url': photoURL,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'version': '1.0.0',
        'fcmToken': _fcmToken,
      },
    }, force: true);
  }

  void _setupMessageListener(String firebaseToken, {String? displayName}) {
    final currentId = _connectionId;

    // Cancel previous subscription to avoid double-processing
    _subscription?.cancel();

    // Listen for messages
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onError: (error) {
        if (currentId != _connectionId) return;
        debugPrint('🚨 WebSocket Error (ID: $currentId): $error');
        _handleConnectionFailure(firebaseToken, displayName: displayName);
      },
      onDone: () {
        if (currentId != _connectionId) return;

        // Check close code to see if it was intentional
        final code = _channel?.closeCode;
        debugPrint(
          '🚨 WebSocket connection closed (ID: $currentId). Code: $code',
        );

        if (_connectionStatus == ConnectionStatus.connected ||
            _connectionStatus == ConnectionStatus.connecting ||
            _connectionStatus == ConnectionStatus.reconnecting) {
          // Unexpected disconnect - try to reconnect
          _handleConnectionFailure(firebaseToken, displayName: displayName);
        }
      },
      cancelOnError: false,
    );
  }

  void _handleConnectionFailure(String firebaseToken, {String? displayName}) {
    // Stop heartbeat immediately to prevent send-after-close errors
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = null;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final baseDelay = _baseReconnectDelay * (1 << (_reconnectAttempts - 1));
      final random = Random();
      final jitter = Duration(milliseconds: random.nextInt(500));
      final delay = baseDelay + jitter;

      debugPrint(
        'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
      );

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(
        delay,
        () => _attemptConnection(firebaseToken, displayName: displayName),
      );

      _updateConnectionStatus(ConnectionStatus.reconnecting);
    } else {
      debugPrint('Max reconnection attempts reached');
      _updateConnectionStatus(ConnectionStatus.failed);

      // Final failure - complete the completer with error
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(
          const NetworkFailure(
            'Server connection failed after multiple retries',
          ),
        );
      }

      if (!_eventController.isClosed) {
        _eventController.add(SessionEventType.connectionFailed);
      }
    }
  }

  void _updateConnectionStatus(ConnectionStatus status) {
    final previousStatus = _connectionStatus;
    _connectionStatus = status;

    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }

    // ✅ Phase 4 UX: Set syncing flag during reconnection
    if (status == ConnectionStatus.reconnecting) {
      _currentState = _currentState.copyWith(isSyncing: true);
      if (!_stateController.isClosed) {
        _stateController.add(_currentState);
      }
    }

    // Provide user-friendly feedback based on status changes
    if (status == ConnectionStatus.connected &&
        previousStatus != ConnectionStatus.connected) {
      debugPrint('✅ Connected to server');
    } else if (status == ConnectionStatus.reconnecting) {
      debugPrint('🔄 Attempting to reconnect...');
    } else if (status == ConnectionStatus.failed) {
      debugPrint('❌ Connection failed');
      // Emit error to notify user
      if (!_errorController.isClosed) {
        _errorController.add(
          const NetworkFailure(
            'Unable to connect to server. Please check your internet connection.',
          ),
        );
      }
    } else if (status == ConnectionStatus.disconnected &&
        previousStatus == ConnectionStatus.connected) {
      debugPrint('📡 Disconnected from server');
    }
  }

  void _send(Map<String, dynamic> message, {bool force = false}) {
    // Check if channel exists and connection status is valid
    if (_channel == null) {
      if (!force && _isQueuable(message['type'])) {
        _queueMessage(message);
      } else {
        debugPrint('⚠️ Cannot send message: WebSocket channel is null');
      }
      return;
    }

    if (!force && _connectionStatus != ConnectionStatus.connected) {
      if (_isQueuable(message['type'])) {
        _queueMessage(message);
      } else {
        debugPrint(
          '⚠️ Cannot send message: Not connected (status: $_connectionStatus)',
        );
        debugPrint('   Dropped message type: ${message['type']}');
      }
      return;
    }

    try {
      // ✅ FIX #8: Add sequence number for ordering validation
      message['seq'] = _nextSequence++;
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      debugPrint('   Message type: ${message['type']}');

      if (_isQueuable(message['type'])) {
        _queueMessage(message);
      }

      // Channel is likely closed, trigger reconnection
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // Update status to trigger reconnection attempt
      if (_connectionStatus == ConnectionStatus.connected) {
        _updateConnectionStatus(ConnectionStatus.disconnected);
      }
    }
  }

  bool _isQueuable(String? type) {
    if (type == null) return false;
    // Queue non-gameplay requests that are useful to have once connected
    const queuable = {
      'FRIEND_LIST',
      'LEADERBOARD_GET',
      'CHALLENGES_GET',
      'REFILL_COINS',
      'UPDATE_FCM',
    };
    return queuable.contains(type);
  }

  void _queueMessage(Map<String, dynamic> message) {
    // Deduplicate: remove existing message of same type
    _messageQueue.removeWhere((m) => m['type'] == message['type']);
    _messageQueue.add(message);
    debugPrint(
      '📫 Queued message: ${message['type']} (${_messageQueue.length} in queue)',
    );
  }

  void _processMessageQueue() {
    if (_connectionStatus != ConnectionStatus.connected ||
        _messageQueue.isEmpty) {
      return;
    }

    debugPrint('📤 Processing ${_messageQueue.length} queued messages...');
    final currentQueue = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final msg in currentQueue) {
      _send(msg);
    }
  }

  void _handleMessage(dynamic data) {
    _lastMessageTime = DateTime.now(); // Reset watchdog

    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String;

      if (type == 'PONG') {
        debugPrint('🏓 PONG received'); // Debug to verify server responding
        return; // Heartbeat response
      }

      switch (type) {
        case 'AUTH_OK':
          // ✅ FIX: Cancel AUTH timeout - we got the response!
          _authTimeoutTimer?.cancel();

          debugPrint('✅ Auth successful: ${msg['data']} (ID: $_connectionId)');
          _updateConnectionStatus(ConnectionStatus.connected);

          // Complete the connection completer
          if (_connectionCompleter != null &&
              !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete();
          }

          _startHeartbeat(); // Start keep-alive and watchdog
          _processMessageQueue(); // Flush any messages queued during connection

          // ✅ FIX: Resend FCM token if we have one (for reconnections)
          if (_fcmToken != null) {
            _send({
              'type': 'UPDATE_FCM',
              'data': {'token': _fcmToken},
            });
            debugPrint('📬 FCM token resent after reconnection');
          }

          // ✅ Session Restoration:
          // The server now automatically restores our CurrentRoom if we were in one.
          // If we receive AUTH_OK, we should check if we already have a game state.
          // If so, we don't need to call joinMatchmaking() manually.
          if (_currentState.roomId != '000' &&
              _currentState.currentPhase != SessionPhase.lobby &&
              _currentState.currentPhase != SessionPhase.finished) {
            debugPrint('📬 Session restored automatically by server');
          }

          // Parse stats from AUTH_OK response
          final authData = msg['data'] as Map<String, dynamic>;

          // Handle Admin Status from Server
          final isAdmin = authData['isAdmin'] as bool? ?? false;
          final playerId = authData['playerId'] as String?;
          if (playerId != null) {
            AppConfig.instance.setAdminStatus(isAdmin, playerId);
          }

          if (authData.containsKey('stats')) {
            try {
              final stats = UserStats.fromJson(
                authData['stats'] as Map<String, dynamic>,
              );
              _lastStats = stats; // Cache stats
              if (!_statsController.isClosed) {
                _statsController.add(stats);
              }
              debugPrint(
                'User stats loaded: ${stats.wins} wins, ${stats.rank} rank',
              );
            } catch (e) {
              debugPrint('Failed to parse stats: $e');
            }
          }

          // NOTE: Removed automatic JOIN_ROOM here.
          // Users must explicitly click "Find Match" to join the matchmaking queue.
          // This prevents unwanted queue joins on every app open/reconnect.

          // Start Lobby Music
          try {
            sl.audioService.playBgm(SoundAssets.lobbyAmbience);
          } catch (e) {
            debugPrint('Failed to start lobby ambience: $e');
          }
          break;

        case 'STATS_UPDATE':
          // Handle real-time stats updates (e.g., after game end)
          try {
            final stats = UserStats.fromJson(
              msg['data'] as Map<String, dynamic>,
            );
            _lastStats = stats; // Cache stats
            if (!_statsController.isClosed) {
              _statsController.add(stats);
            }
            debugPrint('Stats updated: ${stats.wins} wins, ${stats.rank} rank');
          } catch (e) {
            debugPrint('Failed to parse stats update: $e');
          }
          break;

        case 'AUTH_FAIL':
          // Notify user via error stream
          debugPrint('Auth failed: ${msg['data']}');
          if (!_errorController.isClosed) {
            _errorController.add(
              AuthFailure(
                msg['data']['message'] ?? 'Authentication failed',
                msg['data'],
              ),
            );
          }
          break;

        case 'GAME_STATE':
          _handleGameState(msg['data'] as Map<String, dynamic>);
          break;

        case 'GAME_ACTION':
          _handleGameAction(msg['data'] as Map<String, dynamic>);
          break;

        case 'ERROR':
          final errorData = msg['data'] as Map<String, dynamic>;
          // Propagate server errors to the UI
          debugPrint('Server Error: ${errorData['message']}');
          if (!_errorController.isClosed) {
            _errorController.add(
              ServerFailure(
                errorData['message'] ?? 'Unknown server error',
                errorData,
              ),
            );
          }
          break;

        case 'LEADERBOARD_DATA':
          try {
            final data = (msg['data'] as List<dynamic>?) ?? [];
            final leaderboard = data
                .map((u) => UserStats.fromJson(u as Map<String, dynamic>))
                .toList();
            if (!_leaderboardController.isClosed) {
              _leaderboardController.add(leaderboard);
            }
          } catch (e) {
            debugPrint('Failed to parse leaderboard: $e');
          }
          break;

        case 'FRIEND_LIST':
          try {
            final data = (msg['data'] as List<dynamic>?) ?? [];
            final friends = data
                .map((f) => FriendRecord.fromJson(f as Map<String, dynamic>))
                .toList();
            _friends = friends; // Cache friends
            if (!_friendsController.isClosed) {
              _friendsController.add(friends);
            }
          } catch (e) {
            debugPrint('Failed to parse friend list: $e');
          }
          break;

        case 'ROOM_CREATED':
          try {
            final evt = RoomCreated.fromJson(
              msg['data'] as Map<String, dynamic>,
            );
            if (!_roomEventController.isClosed) {
              _roomEventController.add(evt);
            }
          } catch (e) {
            debugPrint('Failed to parse ROOM_CREATED: $e');
          }
          break;

        case 'ROOM_JOINED':
          try {
            final evt = RoomJoined.fromJson(
              msg['data'] as Map<String, dynamic>,
            );
            if (!_roomEventController.isClosed) {
              _roomEventController.add(evt);
            }
          } catch (e) {
            debugPrint('Failed to parse ROOM_JOINED: $e');
          }
          break;

        case 'ROOM_UPDATE':
          try {
            final currentUserId = sl.authRepository.currentUser?.uid;
            final evt = RoomUpdated.fromJson(
              msg['data'] as Map<String, dynamic>,
              currentUserId: currentUserId,
            );
            if (!_roomEventController.isClosed) {
              _roomEventController.add(evt);
            }
          } catch (e) {
            debugPrint('Failed to parse ROOM_UPDATE: $e');
          }
          break;

        case 'VOICE_SDP':
          if (_voiceManager != null) {
            _voiceManager!.handleAnswer(msg['data'] as Map<String, dynamic>);
          }
          break;

        case 'VOICE_ICE':
          if (_voiceManager != null) {
            _voiceManager!.handleCandidate(msg['data'] as Map<String, dynamic>);
          }
          break;

        case 'CHALLENGES_DATA':
          try {
            final data = (msg['data'] as List<dynamic>?) ?? [];
            final challenges = data
                .map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
                .toList();
            if (!_challengesController.isClosed) {
              _challengesController.add(challenges);
            }
          } catch (e) {
            debugPrint('Failed to parse challenges: $e');
          }
          break;

        case 'CHALLENGE_CLAIM_OK':
          try {
            final data = msg['data'] as Map<String, dynamic>;
            if (!_challengeClaimResultController.isClosed) {
              _challengeClaimResultController.add(data);
            }
            // Play a special reward sound
            sl.audioService.playSfx(SoundAssets.turnAlert); // Temporary
          } catch (e) {
            debugPrint('Failed to parse challenge claim reward: $e');
          }
          break;

        case 'CHAT':
          try {
            final data = msg['data'] as Map<String, dynamic>;
            // Add message type so UI knows it is chat
            data['type'] = 'chat';
            if (!_chatController.isClosed) {
              _chatController.add(data);
            }
          } catch (e) {
            debugPrint('Failed to parse chat message: $e');
          }
          break;

        case 'EMOJI':
          try {
            final data = msg['data'] as Map<String, dynamic>;
            // Add message type so UI knows it is emoji
            data['type'] = 'emoji';
            if (!_chatController.isClosed) {
              _chatController.add(data);
            }

            // Play emoji sound
            sl.audioService.playEmojiSound(data['emojiId'] as String);
          } catch (e) {
            debugPrint('Failed to parse emoji message: $e');
          }
          break;

        case 'TYPING':
          try {
            final data = msg['data'] as Map<String, dynamic>;
            final senderId = data['senderId'] as String;
            final isTyping = data['isTyping'] as bool;

            _typingStatus[senderId] = isTyping;
            _activeEventActorId = senderId;
            _eventController.add(SessionEventType.typingStatusChanged);
          } catch (e) {
            debugPrint('Failed to parse typing message: $e');
          }
          break;
      }
    } catch (e, stack) {
      debugPrint('Error handling WebSocket message: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  void _handleGameState(Map<String, dynamic> stateData) {
    // Parse phase
    final phaseStr = stateData['phase'] as String;
    final phase = SessionPhase.values.firstWhere(
      (p) => p.name == phaseStr,
      orElse: () => SessionPhase.lobby,
    );

    // Audio Triggers based on State Changes
    final previousPhase = _currentState.currentPhase;
    // Detect Turn Start
    if (previousPhase != SessionPhase.thinking &&
        phase == SessionPhase.thinking) {
      final activeId = stateData['activePlayerId'] as String?;
      final myId = sl.authRepository.currentUser?.uid;
      if (activeId == myId) {
        // ✅ FIX #15: Wrap audio calls to prevent crashes
        try {
          sl.audioService.playSfx(SoundAssets.turnAlert);
          sl.audioService.triggerHaptic(HapticType.heavy);
        } catch (e) {
          debugPrint('Audio error (turn alert): $e');
        }
      }
    }
    // Detect Challenge
    if (previousPhase != SessionPhase.challenging &&
        phase == SessionPhase.challenging) {
      try {
        sl.audioService.playSfx(SoundAssets.challenge);
        sl.audioService.triggerHaptic(HapticType.error); // Alert vibration
      } catch (e) {
        debugPrint('Audio error (challenge): $e');
      }
    }

    // BGM Lifecycle
    // Stop BGM when entering active gameplay
    if (previousPhase == SessionPhase.lobby && phase != SessionPhase.lobby) {
      try {
        sl.audioService.stopBgm();
      } catch (e) {
        debugPrint('Audio error (stop bgm): $e');
      }
    }
    // Resume BGM when returning to lobby
    if (previousPhase != SessionPhase.lobby && phase == SessionPhase.lobby) {
      try {
        sl.audioService.playBgm(SoundAssets.lobbyAmbience);
      } catch (e) {
        debugPrint('Audio error (resume bgm): $e');
      }
    }

    // Parse participants
    final myId = sl.authRepository.currentUser?.uid;
    final participantsList = stateData['participants'] as List<dynamic>? ?? [];
    final participants = participantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      final pId = pMap['id'] as String?; // Might be null for others
      final sessionId = pMap['sessionId'] as String;
      final isMe = (pId != null && pId == myId);

      return Participant(
        id: isMe ? 'me' : (pId ?? sessionId),
        sessionId: sessionId,
        name: pMap['name'] as String,
        avatarUrl: pMap['avatarUrl'] as String?,
        rank: pMap['rank'] as String?,
        unitCount: pMap['cardCount'] as int,
        isMe: isMe,
        isActive: pMap['isActive'] as bool? ?? false,
        isDisconnected: pMap['isDisconnected'] as bool? ?? false,
      );
    }).toList();

    // Parse my hand
    final myHandList = stateData['myHand'] as List<dynamic>? ?? [];
    final myHand = myHandList.map((c) {
      final card = c as Map<String, dynamic>;
      return Unit(
        id: card['id'] as String,
        type: UnitType.values.firstWhere(
          (t) => t.name == card['type'],
          orElse: () => UnitType.spades,
        ),
        rank: UnitRank.values.firstWhere(
          (r) => r.name == card['rank'],
          orElse: () => UnitRank.two,
        ),
      );
    }).toList();

    final activeId = stateData['activePlayerId'] as String?;

    // Parse rich event data
    final lastEvent = stateData['lastEvent'] as String?;
    final actorId = stateData['lastEventActorId'] as String?;
    final cardCount = stateData['lastEventCardCount'] as int? ?? 0;
    _isBluffSuccessful = stateData['isBluffSuccessful'] as bool?;

    // Parse gameLog
    final logData = stateData['gameLog'] as List<dynamic>?;
    if (logData != null) {
      _gameLog.clear();
      _gameLog.addAll(logData.map((e) => e.toString()));
    }

    // Map actor IDs to 'me'
    _activeEventActorId = actorId == myId ? 'me' : actorId;
    _lastCountClaimed = cardCount;
    _isRevealingBluff = phase == SessionPhase.revealing;

    // Parse lastMove if present
    final lastMoveData = stateData['lastMove'] as Map<String, dynamic>?;
    if (lastMoveData != null) {
      final movePlayerId = lastMoveData['playerId'] as String;
      final declaredRankStr = lastMoveData['declaredRank'] as String;

      _lastMove = GameMove(
        playerId: movePlayerId == myId ? 'me' : movePlayerId,
        declaredRank: UnitRank.values.firstWhere(
          (r) => r.name == declaredRankStr,
          orElse: () => UnitRank.two,
        ),
        actualUnits: [], // Server doesn't send actual cards for security
      );
      _lastRankClaimed = _lastMove?.declaredRank;
    } else {
      _lastMove = null;
      _lastRankClaimed = null;
    }

    final newState = SessionState(
      roomId: 'online',
      participants: participants,
      myHand: myHand,
      pileCount: stateData['pileCount'] as int? ?? 0,
      currentPhase: phase,
      activeParticipantId: activeId == myId ? 'me' : activeId,
      startTime: stateData['startTime'] != null
          ? (stateData['startTime'] as int)
          : null,
      turnStartTime: stateData['turnStartTime'] != null
          ? (stateData['turnStartTime'] as int)
          : null,
      turnTimerS: null, // Timer logic handled via turnStartTime
      isSpectator: stateData['isSpectator'] as bool? ?? false,
      isSyncing: false, // Reset syncing flag on full state sync
      createdAt: stateData['createdAt'] as int?,
    );

    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }

    // Emit events based on lastEvent from server
    // Emit events based on lastEvent from server
    // NEW: Use lastEventId to deduplicate events (prevents multiple animations)
    final lastEventId = stateData['lastEventId'] as String?;

    if (lastEvent != null && !_eventController.isClosed) {
      // If server provides an ID, check if we already processed it
      if (lastEventId != null && lastEventId == _lastProcessedEventId) {
        // Duplicate event, ignore
      } else {
        // New event or legacy/local event
        if (lastEventId != null) {
          _lastProcessedEventId = lastEventId;
        }

        switch (lastEvent) {
          case 'cardsPlayed':
            _eventController.add(SessionEventType.cardsPlayed);
            break;
          case 'passed':
            _eventController.add(SessionEventType.passed);
            break;
          case 'bluffCalled':
            _eventController.add(SessionEventType.bluffCalled);
            break;
          case 'pileDiscarded':
            _eventController.add(SessionEventType.pileDiscarded);
            break;
          case 'cardsPickedUp':
            _eventController.add(SessionEventType.cardsPickedUp);
            break;
          case 'shuffling':
            _eventController.add(SessionEventType.shuffling);
            break;
        }
      }
    }

    // fallback for phase changes if lastEvent is missing
    if (lastEvent == null) {
      if (phase == SessionPhase.thinking) {
        if (!_eventController.isClosed) {
          _eventController.add(SessionEventType.turnChanged);
        }
      }
    }
  }

  /// HYBRID SYSTEM: Handle lightweight action events from server
  void _handleGameAction(Map<String, dynamic> actionData) {
    try {
      final action = actionData['action'] as String?;
      final data = actionData['data'] as Map<String, dynamic>? ?? {};

      if (action == null) return;

      debugPrint('Game Action: $action');

      final myId = sl.authRepository.currentUser?.uid;

      switch (action) {
        case 'PLAY_CARDS':
          // Patch state with lightweight update
          final playerId = data['playerId'] as String?;
          final count = data['count'] as int? ?? 0;
          final newPileCount = data['newPileCount'] as int? ?? 0;
          final nextPlayerId = data['nextPlayerId'] as String?;
          final turnStartTime = data['turnStartTime'] as int?;
          final playerNewCardCount = data['playerNewCardCount'] as int?;

          // ✅ FIX #5: Update participant card count to prevent state drift
          List<Participant> updatedParticipants = _currentState.participants;
          if (playerId != null && playerNewCardCount != null) {
            updatedParticipants = _currentState.participants.map((p) {
              final pId = p.isMe ? myId : p.id;
              if (pId == playerId) {
                return Participant(
                  id: p.id,
                  sessionId: p.sessionId,
                  name: p.name,
                  avatarUrl: p.avatarUrl,
                  rank: p.rank,
                  unitCount: playerNewCardCount,
                  isMe: p.isMe,
                  isActive: p.isActive,
                  isDisconnected: p.isDisconnected,
                );
              }
              return p;
            }).toList();
          }

          // Update current state
          _currentState = _currentState.copyWith(
            pileCount: newPileCount,
            activeParticipantId: nextPlayerId == myId ? 'me' : nextPlayerId,
            currentPhase: SessionPhase.challenging,
            turnStartTime: turnStartTime,
            participants: updatedParticipants,
          );

          // Emit state update
          if (!_stateController.isClosed) {
            _stateController.add(_currentState);
          }

          // Emit event for animations
          _activeEventActorId = playerId == myId ? 'me' : playerId;
          _lastCountClaimed = count;

          if (!_eventController.isClosed) {
            _eventController.add(SessionEventType.cardsPlayed);
          }
          break;

        case 'PASS':
          // Patch state with turn advance
          final nextPlayerId = data['nextPlayerId'] as String?;
          final turnStartTime = data['turnStartTime'] as int?;

          _currentState = _currentState.copyWith(
            activeParticipantId: nextPlayerId == myId ? 'me' : nextPlayerId,
            turnStartTime: turnStartTime,
          );

          if (!_stateController.isClosed) {
            _stateController.add(_currentState);
          }

          // Emit pass event
          final playerId = data['playerId'] as String?;
          _activeEventActorId = playerId == myId ? 'me' : playerId;

          if (!_eventController.isClosed) {
            _eventController.add(SessionEventType.passed);
          }
          break;

        default:
          debugPrint('Unknown game action: $action');
      }
    } catch (e) {
      debugPrint('❌ Error patching game action: $e');
    }
  }

  void receiveVoiceState(Map<String, dynamic> data) {
    _voiceCallback?.call(data);
  }

  @override
  Future<void> raiseHand() async {
    _send({'type': 'VOICE_RAISE_HAND'});
  }

  @override
  void sendVoiceSDP(Map<String, dynamic> data) {
    _send({'type': 'VOICE_SDP', 'data': data});
  }

  @override
  void sendVoiceICE(Map<String, dynamic> data) {
    _send({'type': 'VOICE_ICE', 'data': data});
  }

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    _send({'type': 'START_GAME'});
  }

  @override
  void playCards(List<String> unitIds, UnitRank declaredRank) {
    _send({
      'type': 'PLAY_CARDS',
      'data': {'cardIds': unitIds, 'declaredRank': declaredRank.name},
    });
    try {
      sl.audioService.playSfx(SoundAssets.cardSlide);
      sl.audioService.triggerHaptic(HapticType.light);
    } catch (e) {
      debugPrint('Audio/Haptic error (playCards): $e');
    }
  }

  @override
  void passTurn() {
    _send({'type': 'PASS'});
    try {
      sl.audioService.playSfx(SoundAssets.buttonTap);
      sl.audioService.triggerHaptic(HapticType.medium);
    } catch (e) {
      debugPrint('Audio/Haptic error (passTurn): $e');
    }
  }

  @override
  void raiseChallenge() {
    _send({'type': 'CHALLENGE'});
    try {
      sl.audioService.playSfx(SoundAssets.buttonTap);
      sl.audioService.triggerHaptic(HapticType.heavy);
    } catch (e) {
      debugPrint('Audio/Haptic error (raiseChallenge): $e');
    }
  }

  @override
  void sortHand() {
    // Local operation - sort the hand in state
    final sortedHand = List<Unit>.from(_currentState.myHand)
      ..sort((a, b) {
        if (a.type != b.type) {
          return a.type.index.compareTo(b.type.index);
        }
        return a.rank.index.compareTo(b.rank.index);
      });

    final newState = _currentState.copyWith(myHand: sortedHand);
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  void reorderHand(int oldIndex, int newIndex) {
    // Local operation - reorder hand
    final hand = List<Unit>.from(_currentState.myHand);
    final unit = hand.removeAt(oldIndex);
    hand.insert(newIndex, unit);

    final newState = _currentState.copyWith(myHand: hand);
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  // -- Social & Competitive Methods --

  void refillCoins() {
    _send({'type': 'REFILL_COINS'});
  }

  void requestLeaderboard() {
    _send({'type': 'LEADERBOARD_GET'});
  }

  void requestFriends() {
    _send({'type': 'FRIEND_LIST'});
  }

  void addFriend(String friendId) {
    _send({'type': 'FRIEND_REQUEST', 'data': friendId});
  }

  void acceptFriend(String friendId) {
    _send({'type': 'FRIEND_ACCEPT', 'data': friendId});
  }

  void removeFriend(String friendId) {
    _send({'type': 'FRIEND_REMOVE', 'data': friendId});
  }

  // -- Private Room Methods --

  Future<void> createPrivateRoom({
    required String roomName,
    String? password,
    required int maxPlayers,
    required double bootAmount,
    required bool voiceChat,
    required bool spectatorMode,
  }) async {
    _send({
      'type': 'CREATE_PRIVATE_ROOM',
      'data': {
        'roomName': roomName,
        'password': password,
        'maxPlayers': maxPlayers,
        'bootAmount': bootAmount,
        'voiceChat': voiceChat,
        'spectatorMode': spectatorMode,
      },
    });
  }

  Future<void> joinPrivateRoom(
    String roomCode, {
    String? password,
    bool isSpectator = false,
  }) async {
    _send({
      'type': 'JOIN_PRIVATE_ROOM',
      'data': {
        'roomCode': roomCode,
        'password': password,
        'isSpectator': isSpectator,
      },
    });
  }

  void startPrivateGame(String roomCode) {
    _send({
      'type': 'START_PRIVATE_GAME',
      'data': {'roomCode': roomCode},
    });
  }

  void leaveRoom(String roomCode) {
    _send({
      'type': 'LEAVE_ROOM',
      'data': {'roomCode': roomCode},
    });
  }

  void deleteAccount() {
    _send({'type': 'DELETE_ACCOUNT'});
  }

  /// Join the matchmaking queue for public matches
  void joinMatchmaking() {
    // Check if we are already in an active room (session restoration)
    if (_currentState.roomId != '0' && _currentState.roomId != '000') {
      debugPrint(
        '⚠️ joinMatchmaking skipped: Already in room ${_currentState.roomId}',
      );
      return;
    }

    // ✅ FIX #4: Prevent duplicate matchmaking joins
    if (_isJoiningMatchmaking) {
      debugPrint('⚠️ joinMatchmaking skipped: already joining');
      return;
    }
    _isJoiningMatchmaking = true;
    _send({'type': 'JOIN_ROOM'});
    // Reset flag after a short delay to allow retry if needed
    Future.delayed(const Duration(seconds: 2), () {
      _isJoiningMatchmaking = false;
    });
  }

  /// Cancel matchmaking queue
  void cancelMatchmaking() {
    _send({'type': 'CANCEL_MATCHMAKING'});
    _isJoiningMatchmaking = false;
    debugPrint('📤 CANCEL_MATCHMAKING sent');
  }

  @override
  void sendChatMessage(String message) {
    _send({
      'type': 'CHAT',
      'data': {'message': message},
    });
  }

  @override
  void sendEmojiMessage(String emojiId) {
    _send({
      'type': 'EMOJI',
      'data': {'emojiId': emojiId},
    });
  }

  @override
  void setTypingStatus(bool isTyping) {
    _send({
      'type': 'TYPING',
      'data': {'isTyping': isTyping},
    });
  }

  // -- Daily Challenges --

  void requestChallenges() {
    _send({'type': 'CHALLENGES_GET'});
  }

  void claimChallenge(String challengeId) {
    _send({'type': 'CHALLENGE_CLAIM', 'data': challengeId});
  }

  @override
  void resetGameSession() {
    _friends = [];
    _gameLog.clear();
    _activeEventActorId = null;
    _lastRankClaimed = null;
    _lastCountClaimed = 0;
    _lastBluffWinnerId = null;
    _lastBluffLoserId = null;
    _isBluffSuccessful = null;
    _lastMove = null;
    _isRevealingBluff = false;
    _pNames.clear();
    _typingStatus.clear();
    _lastProcessedEventId = null;
    _messageQueue.clear();

    // Reset state to Initial
    _currentState = SessionState.initial();

    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  @override
  Future<void> dispose() async {
    // NOTE: For Singleton usage, we do NOT close StreamControllers.
    // We only reset the connection state.

    // Cancel all timers
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _reconnectScheduleTimer?.cancel();
    _reconnectScheduleTimer = null;

    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = null;

    _subscription?.cancel();
    _subscription = null;

    _messageQueue.clear();

    // Close WebSocket connection
    await _channel?.sink.close();
    _channel = null;

    _updateConnectionStatus(ConnectionStatus.disconnected);

    // Verify voice manager disposal, might need to be kept alive too?
    // Usually voice depends on active session, so disposing it is fine.
    await _voiceManager?.dispose();

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
  }
}
