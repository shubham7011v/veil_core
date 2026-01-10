import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WebSocketSessionHandler
    implements GameSessionHandler, VoiceSessionHandler {
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

  // Connection state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  bool _isDisposed = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _baseReconnectDelay = Duration(seconds: 2);
  String? _lastUrl;

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
  final int _lastCountClaimed = 0;
  final List<String> _gameLog = [];
  String? _lastBluffWinnerId;
  String? _lastBluffLoserId;
  bool? _isBluffSuccessful;
  GameMove? _lastMove;
  final bool _isRevealingBluff = false;
  final Map<String, String> _pNames = {};

  @override
  Stream<SessionState> get sessionStateStream => _stateController.stream;

  @override
  Stream<SessionEventType> get eventStream => _eventController.stream;

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
    await _attemptConnection(firebaseToken, displayName: displayName);
  }

  Future<void> _attemptConnection(
    String firebaseToken, {
    String? displayName,
  }) async {
    if (_connectionStatus == ConnectionStatus.connecting) return;

    _updateConnectionStatus(
      _reconnectAttempts > 0
          ? ConnectionStatus.reconnecting
          : ConnectionStatus.connecting,
    );

    try {
      // Close existing connection if any to prevent leaks
      await _channel?.sink.close();

      debugPrint('Connecting to WebSocket: $_lastUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_lastUrl!));

      // Monitor if the connection actually connects at the socket level
      _channel!.ready
          .then((_) {
            debugPrint('✅ WebSocket Handshake Ready for $_lastUrl');
          })
          .catchError((e) {
            debugPrint('🚨 WebSocket Handshake Failed for $_lastUrl: $e');
            // Do not call _handleConnectionFailure here, let onDone/onError in _setupMessageListener handle it
          });

      _setupMessageListener(firebaseToken, displayName: displayName);
      _reconnectAttempts = 0; // Reset on success
    } catch (e) {
      debugPrint('Connection attempt failed to $_lastUrl: $e');
      _handleConnectionFailure(firebaseToken, displayName: displayName);
    }
  }

  void _setupMessageListener(String firebaseToken, {String? displayName}) {
    // Send auth message
    _send({
      'type': 'AUTH',
      'data': {
        'token': firebaseToken,
        'name': displayName ?? 'Player',
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'version': '1.0.0',
      },
    });

    // Listen for messages
    _channel!.stream.listen(
      _handleMessage,
      onError: (error) {
        debugPrint('🚨 WebSocket Error: $error');
        _handleConnectionFailure(firebaseToken, displayName: displayName);
      },
      onDone: () {
        debugPrint('🚨 WebSocket connection closed.');
        if (_channel?.closeCode != null) {
          debugPrint('🚨 Close Code: ${_channel?.closeCode}');
          debugPrint('🚨 Close Reason: ${_channel?.closeReason}');
        }

        if (_connectionStatus == ConnectionStatus.connected ||
            _connectionStatus == ConnectionStatus.connecting) {
          // Unexpected disconnect - try to reconnect
          _handleConnectionFailure(firebaseToken, displayName: displayName);
        }
      },
      cancelOnError: false,
    );
  }

  void _handleConnectionFailure(String firebaseToken, {String? displayName}) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final baseDelay = _baseReconnectDelay * (1 << (_reconnectAttempts - 1));
      // Add random jitter (0-500ms) to prevent Thundering Herd
      final jitter = Duration(milliseconds: DateTime.now().millisecond % 500);
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
      if (!_isDisposed && !_eventController.isClosed) {
        _eventController.add(SessionEventType.connectionFailed);
      }
    }
  }

  void _updateConnectionStatus(ConnectionStatus status) {
    if (_isDisposed) return;
    _connectionStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String;

      switch (type) {
        case 'AUTH_OK':
          debugPrint('Auth successful: ${msg['data']}');
          _updateConnectionStatus(ConnectionStatus.connected);

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
              if (!_isDisposed && !_statsController.isClosed) {
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
            if (!_isDisposed && !_statsController.isClosed) {
              _statsController.add(stats);
            }
            debugPrint('Stats updated: ${stats.wins} wins, ${stats.rank} rank');
          } catch (e) {
            debugPrint('Failed to parse stats update: $e');
          }
          break;

        case 'AUTH_FAIL':
          // TODO: Implement better handling for AUTH_FAIL (e.g., notify user via event stream)
          debugPrint('Auth failed: ${msg['data']}');
          break;

        case 'GAME_STATE':
          _handleGameState(msg['data'] as Map<String, dynamic>);
          break;

        case 'ERROR':
          final errorData = msg['data'] as Map<String, dynamic>;
          // TODO: Propagate server errors to the UI via an error stream or notification bloc
          debugPrint('Server Error: ${errorData['message']}');
          break;

        case 'LEADERBOARD_DATA':
          try {
            final data = (msg['data'] as List<dynamic>?) ?? [];
            final leaderboard = data
                .map((u) => UserStats.fromJson(u as Map<String, dynamic>))
                .toList();
            if (!_isDisposed && !_leaderboardController.isClosed) {
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
            if (!_isDisposed && !_friendsController.isClosed) {
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
            if (!_isDisposed && !_roomEventController.isClosed) {
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
            if (!_isDisposed && !_roomEventController.isClosed) {
              _roomEventController.add(evt);
            }
          } catch (e) {
            debugPrint('Failed to parse ROOM_JOINED: $e');
          }
          break;

        case 'ROOM_UPDATE':
          try {
            final evt = RoomUpdated.fromJson(
              msg['data'] as Map<String, dynamic>,
            );
            if (!_isDisposed && !_roomEventController.isClosed) {
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
            if (!_isDisposed && !_challengesController.isClosed) {
              _challengesController.add(challenges);
            }
          } catch (e) {
            debugPrint('Failed to parse challenges: $e');
          }
          break;

        case 'CHALLENGE_CLAIM_OK':
          try {
            final data = msg['data'] as Map<String, dynamic>;
            if (!_isDisposed && !_challengeClaimResultController.isClosed) {
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
            if (!_isDisposed && !_chatController.isClosed) {
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
            if (!_isDisposed && !_chatController.isClosed) {
              _chatController.add(data);
            }

            // Play emoji sound
            sl.audioService.playSfx(
              SoundAssets.turnAlert,
            ); // Reusing alert for now
          } catch (e) {
            debugPrint('Failed to parse emoji message: $e');
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
        sl.audioService.playSfx(SoundAssets.turnAlert);
        sl.audioService.triggerHaptic(HapticType.heavy);
      }
    }
    // Detect Challenge
    if (previousPhase != SessionPhase.challenging &&
        phase == SessionPhase.challenging) {
      sl.audioService.playSfx(SoundAssets.challenge);
      sl.audioService.triggerHaptic(HapticType.error); // Alert vibration
    }

    // BGM Lifecycle
    // Stop BGM when entering active gameplay
    if (previousPhase == SessionPhase.lobby && phase != SessionPhase.lobby) {
      sl.audioService.stopBgm();
    }
    // Resume BGM when returning to lobby
    if (previousPhase != SessionPhase.lobby && phase == SessionPhase.lobby) {
      sl.audioService.playBgm(SoundAssets.lobbyAmbience);
    }

    // Parse participants
    final participantsList = stateData['participants'] as List<dynamic>? ?? [];
    final participants = participantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      return Participant(
        id: pMap['id'] as String,
        name: pMap['name'] as String,
        unitCount: pMap['cardCount'] as int,
        isMe: false, // Will be set based on player ID match
        isActive: pMap['isActive'] as bool? ?? false,
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

    final newState = SessionState(
      roomId: 'online',
      participants: participants,
      myHand: myHand,
      pileCount: stateData['pileCount'] as int? ?? 0,
      currentPhase: phase,
      activeParticipantId: stateData['activePlayerId'] as String?,
      isSpectator: stateData['isSpectator'] as bool? ?? false,
    );

    _currentState = newState;
    if (!_isDisposed && !_stateController.isClosed) {
      _stateController.add(newState);
    }

    // Emit events based on phase transitions
    if (phase == SessionPhase.thinking) {
      if (!_isDisposed && !_eventController.isClosed) {
        _eventController.add(SessionEventType.turnChanged);
      }
    } else if (phase == SessionPhase.challenging) {
      if (!_isDisposed && !_eventController.isClosed) {
        _eventController.add(SessionEventType.cardsPlayed);
      }
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
    sl.audioService.playSfx(SoundAssets.cardSlide);
    sl.audioService.triggerHaptic(HapticType.light);
  }

  @override
  void passTurn() {
    _send({'type': 'PASS'});
    sl.audioService.playSfx(SoundAssets.buttonTap);
    sl.audioService.triggerHaptic(HapticType.medium);
  }

  @override
  void raiseChallenge() {
    _send({'type': 'CHALLENGE'});
    sl.audioService.playSfx(SoundAssets.buttonTap);
    sl.audioService.triggerHaptic(HapticType.heavy);
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
    if (!_isDisposed && !_stateController.isClosed) {
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
    if (!_isDisposed && !_stateController.isClosed) {
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
    _send({'type': 'JOIN_ROOM'});
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

  // -- Daily Challenges --

  void requestChallenges() {
    _send({'type': 'CHALLENGES_GET'});
  }

  void claimChallenge(String challengeId) {
    _send({'type': 'CHALLENGE_CLAIM', 'data': challengeId});
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    await _connectionStatusController.close();
    await _stateController.close();
    await _eventController.close();
    await _statsController.close();
    await _leaderboardController.close();
    await _friendsController.close();
    await _roomEventController.close();
    await _challengesController.close();
    await _challengeClaimResultController.close();
    await _chatController.close();
    await _voiceManager?.dispose();
  }
}
