import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../di/service_locator.dart';
import '../../../../error/failure.dart';
import '../../../domain/models/session_enums.dart';
import '../../../../utils/app_logger.dart';
import 'websocket_handler_base.dart';

mixin WebSocketConnectionMixin on WebSocketHandlerBase, WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycleChange(state);
  }

  static const int _maxReconnectAttempts = 5;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  static const Duration _authTimeout = Duration(seconds: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const Duration _watchdogTimeout = Duration(seconds: 12);
  static const Duration _tokenRefreshCooldown = Duration(seconds: 30);

  DateTime? _lastTokenRefreshTime;
  String? _cachedToken;

  /// Connect to WebSocket server
  Future<void> connect(
    String serverUrl,
    String firebaseToken, {
    String? displayName,
  }) async {
    lastUrl = serverUrl;

    if (connectionStatus == ConnectionStatus.connected) return;

    // If already connecting, wait for the existing completer
    if (isConnecting &&
        connectionCompleter != null &&
        !connectionCompleter!.isCompleted) {
      AppLogger.networkEvent('⌛ Waiting for existing connection attempt...');
      return connectionCompleter!.future;
    }

    // Reset attempt counter for new explicit connection
    reconnectAttempts = 0;

    connectionCompleter = Completer<void>();
    // Start attempt without awaiting it here, we await the completer instead
    attemptConnection(firebaseToken, displayName: displayName);

    return connectionCompleter!.future;
  }

  Future<void> attemptConnection(
    String firebaseToken, {
    String? displayName,
  }) async {
    // ✅ FIX: Connection mutex to prevent duplicate attempts
    if (isConnecting) {
      AppLogger.warning(
        '⚠️ Connection already in progress, skipping duplicate attempt',
      );
      return;
    }

    if (connectionStatus == ConnectionStatus.connected) return;

    isConnecting = true; // Lock
    connectionId++; // Increment connection instance identity
    final currentId = connectionId;

    updateConnectionStatus(
      reconnectAttempts > 0
          ? ConnectionStatus.reconnecting
          : ConnectionStatus.connecting,
    );

    try {
      try {
        // Stop current heartbeat before changing channel
        heartbeatTimer?.cancel();
        heartbeatTimer = null;

        // Close existing channel safely
        if (channel != null) {
          try {
            await channel?.sink.close();
          } catch (_) {}
          channel = null;
        }

        AppLogger.networkEvent(
          'Connecting to WebSocket (ID: $currentId): $lastUrl',
        );
        channel = WebSocketChannel.connect(Uri.parse(lastUrl!));

        // ✅ FIX: Wait for handshake before sending AUTH
        // Use a shorter timeout for the handshake itself
        await channel!.ready.timeout(const Duration(seconds: 8));

        // If we were interrupted by a newer connection, stop here
        if (currentId != connectionId) {
          AppLogger.networkEvent(
            '🚫 Connection ID $currentId superseded by $connectionId',
          );
          return;
        }

        AppLogger.networkEvent(
          '✅ WebSocket Handshake Ready (ID: $currentId) - Sending AUTH',
        );

        setupMessageListener(firebaseToken, displayName: displayName);
        sendAuthRequest(firebaseToken, displayName: displayName);
      } catch (e) {
        if (currentId != connectionId) return;
        AppLogger.networkError(
          '🚨 [WebSocket] Connection Error (ID: $currentId)',
          exception: e,
        );
        handleConnectionFailure(firebaseToken, displayName: displayName);
      }
    } catch (e) {
      AppLogger.networkError(
        '🚨 [WebSocket] Unexpected error in _attemptConnection',
        exception: e,
      );
      if (currentId == connectionId) {
        handleConnectionFailure(firebaseToken, displayName: displayName);
      }
    } finally {
      // Small delay before releasing lock to prevent immediate flapping
      Future.delayed(const Duration(milliseconds: 100), () {
        if (currentId == connectionId) {
          isConnecting = false;
        }
      });
    }
  }

  void sendAuthRequest(String firebaseToken, {String? displayName}) {
    // ✅ FIX #12: Cancel any existing auth timeout first
    authTimeoutTimer?.cancel();
    authTimeoutTimer = Timer(_authTimeout, () {
      if (connectionStatus != ConnectionStatus.connected) {
        AppLogger.networkError('❌ AUTH_OK timeout - no response from server');
        // Cleanup channel state
        try {
          channel?.sink.close(1008, 'Auth timeout');
        } catch (_) {}
        channel = null;
        handleConnectionFailure(firebaseToken, displayName: displayName);
      }
    });

    final photoURL = sl.authRepository.currentUser?.photoURL;
    sendMessage({
      'type': 'AUTH',
      'data': {
        'token': firebaseToken,
        'name': displayName ?? 'Player',
        'avatar_url': photoURL,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'version': '1.0.0',
        'fcmToken': fcmToken,
      },
    }, force: true);
  }

  // This needs to be overridden or implemented by the main class since it handles messages
  void setupMessageListener(String firebaseToken, {String? displayName});

  void handleConnectionFailure(String firebaseToken, {String? displayName}) {
    // Stop heartbeat immediately to prevent send-after-close errors
    heartbeatTimer?.cancel();
    heartbeatTimer = null;

    authTimeoutTimer?.cancel();
    authTimeoutTimer = null;

    if (reconnectAttempts < _maxReconnectAttempts) {
      reconnectAttempts++;
      final baseDelay = _baseReconnectDelay * (1 << (reconnectAttempts - 1));
      final random = Random();
      final jitter = Duration(milliseconds: random.nextInt(500));
      final delay = baseDelay + jitter;

      AppLogger.networkEvent(
        'Reconnecting in ${delay.inSeconds}s (attempt $reconnectAttempts/$_maxReconnectAttempts)',
      );

      reconnectTimer?.cancel();
      reconnectTimer = Timer(delay, () async {
        // ✅ FIX: Refresh token before retrying to avoid reusing stale/placeholder tokens
        try {
          final user = sl.authRepository.currentUser;
          if (user == null) {
            AppLogger.warning('❌ No user found for reconnection');
            updateConnectionStatus(ConnectionStatus.failed);
            return;
          }

          AppLogger.networkEvent('🔄 Refreshing auth token before retry...');
          final freshToken = await _getFreshToken(user);

          if (freshToken != null) {
            await attemptConnection(
              freshToken,
              displayName: displayName ?? user.displayName,
            );
          } else {
            AppLogger.error('❌ Failed to refresh token');
            updateConnectionStatus(ConnectionStatus.failed);
          }
        } catch (e) {
          AppLogger.error('❌ Token refresh failed', exception: e);
          // Fall back to using the old token as a last resort
          attemptConnection(firebaseToken, displayName: displayName);
        }
      });

      updateConnectionStatus(ConnectionStatus.reconnecting);
    } else {
      AppLogger.networkError('Max reconnection attempts reached');
      updateConnectionStatus(ConnectionStatus.failed);

      // Final failure - complete the completer with error
      if (connectionCompleter != null && !connectionCompleter!.isCompleted) {
        connectionCompleter!.completeError(
          const NetworkFailure(
            'Server connection failed after multiple retries',
          ),
        );
      }

      if (!eventController.isClosed) {
        eventController.add(SessionEventType.connectionFailed);
      }
    }
  }

  void updateConnectionStatus(ConnectionStatus status) {
    final previousStatus = connectionStatus;
    connectionStatus = status;
    AppLogger.networkEvent(
      '🔌 [WebSocket] Status changed: $previousStatus -> $status',
    );

    if (!connectionStatusController.isClosed) {
      connectionStatusController.add(status);
    }

    // ✅ Phase 4 UX: Set syncing flag during reconnection
    if (status == ConnectionStatus.reconnecting) {
      currentSessionState = currentSessionState.copyWith(isSyncing: true);
      if (!stateStreamController.isClosed) {
        stateStreamController.add(currentSessionState);
      }
    } else if (status == ConnectionStatus.connected) {
      // ✅ FIX: Ensure syncing flag is cleared when connected
      if (currentSessionState.isSyncing) {
        currentSessionState = currentSessionState.copyWith(isSyncing: false);
        if (!stateStreamController.isClosed) {
          stateStreamController.add(currentSessionState);
        }
      }
    }

    // Provide user-friendly feedback based on status changes
    if (status == ConnectionStatus.connected &&
        previousStatus != ConnectionStatus.connected) {
      AppLogger.networkEvent('✅ Connected to server');
    } else if (status == ConnectionStatus.reconnecting) {
      AppLogger.networkEvent('🔄 Attempting to reconnect...');
    } else if (status == ConnectionStatus.failed) {
      AppLogger.networkEvent('❌ Connection failed');
      // Emit error to notify user
      if (!errorController.isClosed) {
        errorController.add(
          const NetworkFailure(
            'Unable to connect to server. Please check your internet connection.',
          ),
        );
      }
    } else if (status == ConnectionStatus.disconnected &&
        previousStatus == ConnectionStatus.connected) {
      AppLogger.networkEvent('📡 Disconnected from server');
    }
  }

  @override
  void sendMessage(Map<String, dynamic> message, {bool force = false}) {
    // Check if channel exists and connection status is valid
    if (channel == null) {
      if (!force && isQueuable(message['type'] as String?)) {
        queueMessage(message);
      } else {
        AppLogger.warning('⚠️ Cannot send message: WebSocket channel is null');
      }
      return;
    }

    if (!force && connectionStatus != ConnectionStatus.connected) {
      if (isQueuable(message['type'] as String?)) {
        queueMessage(message);
      } else {
        AppLogger.warning(
          '⚠️ Cannot send message: Not connected (status: $connectionStatus)',
        );
        AppLogger.info('   Dropped message type: ${message['type']}');
      }
      return;
    }

    try {
      // ✅ FIX #8: Add sequence number for ordering validation
      message['seq'] = nextSequence++;
      final encoded = jsonEncode(message);
      AppLogger.networkEvent(
        '📤 [WebSocket] Sending: ${message['type']} (seq: ${message['seq']})',
      );
      channel!.sink.add(encoded);
    } catch (e) {
      AppLogger.networkError('❌ Failed to send message', exception: e);
      AppLogger.info('   Message type: ${message['type']}');

      if (isQueuable(message['type'] as String?)) {
        queueMessage(message);
      }

      // Channel is likely closed, trigger reconnection
      heartbeatTimer?.cancel();
      heartbeatTimer = null;

      // Update status to trigger reconnection attempt
      if (connectionStatus == ConnectionStatus.connected) {
        updateConnectionStatus(ConnectionStatus.disconnected);
      }
    }
  }

  bool isQueuable(String? type) {
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

  void queueMessage(Map<String, dynamic> message) {
    // Deduplicate: remove existing message of same type
    messageQueue.removeWhere((m) => m['type'] == message['type']);
    messageQueue.add(message);
    AppLogger.info(
      '📫 Queued message: ${message['type']} (${messageQueue.length} in queue)',
    );
  }

  void processMessageQueue() {
    if (connectionStatus != ConnectionStatus.connected ||
        messageQueue.isEmpty) {
      return;
    }

    AppLogger.info('📤 Processing ${messageQueue.length} queued messages...');
    final currentQueue = List<Map<String, dynamic>>.from(messageQueue);
    messageQueue.clear();

    for (final msg in currentQueue) {
      sendMessage(msg);
    }
  }

  void startHeartbeat() {
    heartbeatTimer?.cancel();
    lastMessageTime = DateTime.now();

    heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (connectionStatus == ConnectionStatus.disconnected) {
        timer.cancel();
        return;
      }

      if (channel != null) {
        try {
          channel!.sink.add(
            jsonEncode({'type': 'PING', 'seq': nextSequence++}),
          );
        } catch (e) {
          AppLogger.networkError('⚠️ Heartbeat send failed', exception: e);
        }
      }

      // 2. Watchdog: check if we've heard from server recently
      final idleTime = DateTime.now().difference(lastMessageTime);

      // ✅ FIX #9: Auto-extend timeout if we are roaming/switching networks (simple heuristic)
      var currentTimeout = _watchdogTimeout;
      if (connectionStatus == ConnectionStatus.reconnecting) {
        currentTimeout = const Duration(
          seconds: 20,
        ); // Give more time during reconnect
      }

      if (idleTime > currentTimeout) {
        AppLogger.networkError(
          '! Watchdog: No server activity for ${idleTime.inSeconds}s (Limit: ${currentTimeout.inSeconds}s). Reconnecting...',
        );
        // Stop heartbeat BEFORE closing to prevent send-after-close errors
        timer.cancel();
        heartbeatTimer = null;

        // Only trigger failure if we aren't already failed/disconnected
        if (connectionStatus != ConnectionStatus.disconnected) {
          updateConnectionStatus(ConnectionStatus.reconnecting);
          // ✅ FIX: Use 1001 (Going Away) instead of reserved 1006
          try {
            channel?.sink.close(1001, 'Watchdog timeout');
          } catch (_) {}
          channel = null;
        }
      }
    });
  }

  void handleLifecycleChange(AppLifecycleState state) {
    AppLogger.info('🔄 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Keep connection alive in background/inactive state indefinitely
        AppLogger.info(
          '📱 App backgrounded/inactive, keeping connection alive',
        );
        break;

      case AppLifecycleState.resumed:
        // App foregrounded - attempt reconnection with delay
        AppLogger.info('📱 App resumed, scheduling connection check');
        scheduleReconnectIfNeeded();
        break;

      default:
        break;
    }
  }

  Timer? _connectivityDebounceTimer;

  Future<void> handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    // Cancel existing timer to debounce
    _connectivityDebounceTimer?.cancel();

    // Debounce for 1.5 seconds to let network settle (e.g. 4G -> Null -> WiFi)
    _connectivityDebounceTimer = Timer(
      const Duration(milliseconds: 1500),
      () async {
        await _processConnectivityChange(results);
      },
    );
  }

  Future<void> _processConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    // Re-check current status as the passed 'results' might be stale after delay
    final currentResults = await Connectivity().checkConnectivity();
    final hasConnection = currentResults.any(
      (r) => r != ConnectivityResult.none,
    );

    if (!hasConnection) {
      AppLogger.networkEvent('❌ Network lost (Debounced)');
      return;
    }

    AppLogger.networkEvent('🌐 Network changed (Debounced): $currentResults');

    // If connected: socket is likely dead/zombie due to IP change. Force reconnect.
    if (connectionStatus == ConnectionStatus.connected) {
      AppLogger.networkEvent(
        '🔄 Network switch detected while connected. Restarting connection...',
      );

      // Comprehensive cleanup before reconnecting
      _cleanupConnectionState();

      // Mark as reconnecting immediately to block potential sends
      updateConnectionStatus(ConnectionStatus.reconnecting);

      // Reset retry counter for fresh start on network switch
      reconnectAttempts = 0;

      return attemptAutoReconnect(force: true);
    }

    // If we were stuck in reconnecting/failed/disconnected, try now!
    // Also restart if we were 'connecting' but network switched (old attempt is doomed)
    if (connectionStatus == ConnectionStatus.reconnecting ||
        connectionStatus == ConnectionStatus.failed ||
        connectionStatus == ConnectionStatus.disconnected ||
        connectionStatus == ConnectionStatus.connecting) {
      AppLogger.networkEvent(
        '🚀 Network restored/switched. Triggering connection immediately.',
      );

      // Comprehensive cleanup before reconnecting
      _cleanupConnectionState();

      // Reset retry counter for fresh start
      reconnectAttempts = 0;

      return attemptAutoReconnect(force: true);
    }
  }

  /// Schedule reconnection with delay to handle edge cases
  static Timer? _reconnectScheduleTimer;

  Future<void> scheduleReconnectIfNeeded() async {
    // Cancel any existing scheduled reconnect
    _reconnectScheduleTimer?.cancel();

    // Wait a bit to allow the app to fully resume and Firebase to be ready
    _reconnectScheduleTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        if (connectionStatus != ConnectionStatus.connected &&
            connectionStatus != ConnectionStatus.connecting) {
          AppLogger.info('🔄 Scheduled reconnection triggered');
          await attemptAutoReconnect();
        } else {
          // Already connected? Let's verify it's not a zombie connection
          if (connectionStatus == ConnectionStatus.connected) {
            AppLogger.info('⚡ Verifying connection integrity on resume...');
            // Sending a ping will trigger immediate write error if socket is effectively dead
            try {
              sendMessage({'type': 'PING', 'seq': nextSequence++}, force: true);
              // If that succeeded, we are likely okay, but let's ensure heartbeat is running
              if (heartbeatTimer == null || !heartbeatTimer!.isActive) {
                startHeartbeat();
              }
            } catch (_) {
              // sendMessage handles the error logging and reconnection trigger
            }
          }
        }
      } catch (e) {
        AppLogger.error('❌ Scheduled reconnect error', exception: e);
      }
    });
  }

  /// Force reconnection attempt (e.g., from notification handler)
  Future<void> forceReconnect() async {
    AppLogger.info('🔄 Force reconnect requested');
    if (connectionStatus == ConnectionStatus.connected) {
      AppLogger.info('⚠️ Already connected, skipping force reconnect');
      return;
    }
    return attemptAutoReconnect(force: true);
  }

  bool _isAutoReconnecting = false;

  Future<void> attemptAutoReconnect({bool force = false}) async {
    // Don't auto-reconnect if we are already connected or connecting
    // Also check our own lock to prevent parallel token fetches
    if (!force &&
        (connectionStatus == ConnectionStatus.connected ||
            connectionStatus == ConnectionStatus.connecting ||
            isConnecting ||
            _isAutoReconnecting)) {
      AppLogger.info('⚠️ Auto-reconnect skipped: Already in progress');
      return;
    }

    _isAutoReconnecting = true;

    try {
      final user = sl.authRepository.currentUser;
      if (user == null) {
        AppLogger.warning('❌ No user found for auto-reconnect');
        return;
      }

      // ✅ FIX: Force token refresh with cooldown to avoid "Too many attempts"
      final token = await _getFreshToken(user);
      final displayName = user.displayName;

      // Check status again after the async token fetch (in case it changed)
      if (connectionStatus == ConnectionStatus.connected ||
          connectionStatus == ConnectionStatus.connecting) {
        AppLogger.info(
          '⚠️ Connection established during token fetch, skipping.',
        );
        return;
      }

      if (token != null && lastUrl != null) {
        AppLogger.info('🔄 Auto-reconnecting with fresh token...');
        // Don't reset attempts here - let the caller decide (network switch already resets)
        // ✅ FIX: Don't await the full connection here, just ensure it's started.
        // This allows the _isAutoReconnecting lock to be released sooner and
        // allows subsequent triggers (like network switches) to be processed.
        unawaited(connect(lastUrl!, token, displayName: displayName));
      }
    } catch (e) {
      AppLogger.error('❌ Auto-reconnect failed', exception: e);
      // If token refresh fails, user needs to re-authenticate
      if (!errorController.isClosed) {
        errorController.add(
          const AuthFailure('Session expired. Please sign in again.'),
        );
      }
    } finally {
      _isAutoReconnecting = false;
    }
  }

  /// Comprehensive cleanup of connection state
  /// Called before starting a fresh connection attempt (e.g., network switch)
  void _cleanupConnectionState() {
    AppLogger.networkEvent('🧹 Cleaning up connection state...');

    // Cancel all timers
    heartbeatTimer?.cancel();
    heartbeatTimer = null;

    authTimeoutTimer?.cancel();
    authTimeoutTimer = null;

    watchdogTimer?.cancel();
    watchdogTimer = null;

    reconnectTimer?.cancel();
    reconnectTimer = null;

    // Close channel safely
    try {
      channel?.sink.close();
    } catch (_) {}
    channel = null;

    // Cancel active subscription
    subscription?.cancel();
    subscription = null;

    // Increment connection ID to invalidate old attempts
    connectionId++;

    // Break connection lock
    isConnecting = false;

    AppLogger.networkEvent(
      '✅ Connection state cleaned (ID now: $connectionId)',
    );
  }

  /// Helper to fetch a fresh token with exponential backoff/cooldown
  Future<String?> _getFreshToken(dynamic user) async {
    final now = DateTime.now();

    // 1. If we have a cached token and it's within the cooldown period, reuse it
    if (_cachedToken != null &&
        _lastTokenRefreshTime != null &&
        now.difference(_lastTokenRefreshTime!) < _tokenRefreshCooldown) {
      AppLogger.info(
        '🛡️ Token refresh cooldown active (${now.difference(_lastTokenRefreshTime!).inSeconds}s ago). Reusing cached token.',
      );
      return _cachedToken;
    }

    try {
      // 2. Fetch fresh token from Firebase
      final token = await user.getIdToken(true);
      if (token != null) {
        _cachedToken = token;
        _lastTokenRefreshTime = now;
      }
      return token;
    } catch (e) {
      AppLogger.error('❌ Firebase token refresh failed', exception: e);
      // Return cached token as last resort if fetch fails
      return _cachedToken;
    }
  }
}
