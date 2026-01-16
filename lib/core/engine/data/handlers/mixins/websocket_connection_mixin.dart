import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../di/service_locator.dart';
import '../../../../error/failure.dart';
import '../../../domain/models/session_enums.dart';
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
      debugPrint('⌛ Waiting for existing connection attempt...');
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
      debugPrint(
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

        debugPrint('Connecting to WebSocket (ID: $currentId): $lastUrl');
        channel = WebSocketChannel.connect(Uri.parse(lastUrl!));

        // ✅ FIX: Wait for handshake before sending AUTH
        // Use a shorter timeout for the handshake itself
        await channel!.ready.timeout(const Duration(seconds: 8));

        // If we were interrupted by a newer connection, stop here
        if (currentId != connectionId) {
          debugPrint('🚫 Connection ID $currentId superseded by $connectionId');
          return;
        }

        debugPrint(
          '✅ WebSocket Handshake Ready (ID: $currentId) - Sending AUTH',
        );

        setupMessageListener(firebaseToken, displayName: displayName);
        sendAuthRequest(firebaseToken, displayName: displayName);
      } catch (e) {
        if (currentId != connectionId) return;
        debugPrint('🚨 [WebSocket] Connection Error (ID: $currentId): $e');
        handleConnectionFailure(firebaseToken, displayName: displayName);
      }
    } catch (e) {
      debugPrint('🚨 [WebSocket] Unexpected error in _attemptConnection: $e');
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
        debugPrint('❌ AUTH_OK timeout - no response from server');
        // Check if channel is still open before closing
        if (channel != null) {
          channel?.sink.close(1008, 'Auth timeout');
        }
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

      debugPrint(
        'Reconnecting in ${delay.inSeconds}s (attempt $reconnectAttempts/$_maxReconnectAttempts)',
      );

      reconnectTimer?.cancel();
      reconnectTimer = Timer(
        delay,
        () => attemptConnection(firebaseToken, displayName: displayName),
      );

      updateConnectionStatus(ConnectionStatus.reconnecting);
    } else {
      debugPrint('Max reconnection attempts reached');
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
    debugPrint('🔌 [WebSocket] Status changed: $previousStatus -> $status');

    if (!connectionStatusController.isClosed) {
      connectionStatusController.add(status);
    }

    // ✅ Phase 4 UX: Set syncing flag during reconnection
    if (status == ConnectionStatus.reconnecting) {
      currentSessionState = currentSessionState.copyWith(isSyncing: true);
      if (!stateStreamController.isClosed) {
        stateStreamController.add(currentSessionState);
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
      if (!errorController.isClosed) {
        errorController.add(
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

  @override
  void sendMessage(Map<String, dynamic> message, {bool force = false}) {
    // Check if channel exists and connection status is valid
    if (channel == null) {
      if (!force && isQueuable(message['type'] as String?)) {
        queueMessage(message);
      } else {
        debugPrint('⚠️ Cannot send message: WebSocket channel is null');
      }
      return;
    }

    if (!force && connectionStatus != ConnectionStatus.connected) {
      if (isQueuable(message['type'] as String?)) {
        queueMessage(message);
      } else {
        debugPrint(
          '⚠️ Cannot send message: Not connected (status: $connectionStatus)',
        );
        debugPrint('   Dropped message type: ${message['type']}');
      }
      return;
    }

    try {
      // ✅ FIX #8: Add sequence number for ordering validation
      message['seq'] = nextSequence++;
      final encoded = jsonEncode(message);
      debugPrint(
        '📤 [WebSocket] Sending: ${message['type']} (seq: ${message['seq']})',
      );
      channel!.sink.add(encoded);
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      debugPrint('   Message type: ${message['type']}');

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
    debugPrint(
      '📫 Queued message: ${message['type']} (${messageQueue.length} in queue)',
    );
  }

  void processMessageQueue() {
    if (connectionStatus != ConnectionStatus.connected ||
        messageQueue.isEmpty) {
      return;
    }

    debugPrint('📤 Processing ${messageQueue.length} queued messages...');
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
          debugPrint('⚠️ Heartbeat send failed: $e');
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
        debugPrint(
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
    debugPrint('🔄 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Keep connection alive in background/inactive state indefinitely
        debugPrint('📱 App backgrounded/inactive, keeping connection alive');
        break;

      case AppLifecycleState.resumed:
        // App foregrounded - attempt reconnection with delay
        debugPrint('📱 App resumed, scheduling connection check');
        scheduleReconnectIfNeeded();
        break;

      default:
        break;
    }
  }

  /// Schedule reconnection with delay to handle edge cases
  static Timer? _reconnectScheduleTimer;

  Future<void> scheduleReconnectIfNeeded() async {
    // Cancel any existing scheduled reconnect
    _reconnectScheduleTimer?.cancel();

    // Wait a bit to allow the app to fully resume and Firebase to be ready
    _reconnectScheduleTimer = Timer(
      const Duration(milliseconds: 300),
      () async {
        try {
          if (connectionStatus != ConnectionStatus.connected &&
              connectionStatus != ConnectionStatus.connecting) {
            debugPrint('🔄 Scheduled reconnection triggered');
            await attemptAutoReconnect();
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
  Future<void> forceReconnect() async {
    debugPrint('🔄 Force reconnect requested');
    if (connectionStatus == ConnectionStatus.connected) {
      debugPrint('⚠️ Already connected, skipping force reconnect');
      return;
    }
    return attemptAutoReconnect();
  }

  Future<void> attemptAutoReconnect() async {
    // Don't auto-reconnect if we are already connected or connecting
    if (connectionStatus == ConnectionStatus.connected ||
        connectionStatus == ConnectionStatus.connecting ||
        isConnecting) {
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

      if (token != null && lastUrl != null) {
        debugPrint('🔄 Auto-reconnecting with fresh token...');
        // Reset attempts to 0 for a fresh start on resume
        reconnectAttempts = 0;
        await connect(lastUrl!, token, displayName: displayName);
      }
    } catch (e) {
      debugPrint('❌ Auto-reconnect failed: $e');
      // If token refresh fails, user needs to re-authenticate
      if (!errorController.isClosed) {
        errorController.add(
          const AuthFailure('Session expired. Please sign in again.'),
        );
      }
    }
  }
}
