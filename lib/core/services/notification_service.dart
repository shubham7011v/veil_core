import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/notifications/bloc/app_notification_event.dart';
import 'package:veil_core/core/config/app_config.dart';
import 'package:veil_core/core/engine/domain/models/session_enums.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `await Firebase.initializeApp()` here.
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  // Lazy initialization to avoid NotInitializedError before Firebase.initializeApp()
  FirebaseMessaging? _fcmInstance;
  FirebaseMessaging get _fcm {
    _fcmInstance ??= FirebaseMessaging.instance;
    return _fcmInstance!;
  }

  static bool _backgroundHandlerRegistered = false;

  Future<void> initialize() async {
    // 1. Request Permission (critical for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false, // Critical alerts if needed
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
      return;
    }

    // 2. Set Foreground Notification Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );

        // Show in-app notification via Bloc
        sl.notificationBloc.add(
          ShowInfoNotification(
            "${message.notification!.title}: ${message.notification!.body}",
          ),
        );
      }
    });

    // 3. Set Background/Terminated Handler
    if (!_backgroundHandlerRegistered) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      _backgroundHandlerRegistered = true;
      debugPrint('FCM Background Handler registered');
    }

    // 4. Handle notification tap when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _handleMessageInteraction(message);
    });

    // 5. Handle notification tap when app was terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageInteraction(initialMessage);
    }

    // 6. Get Token
    final token = await _fcm.getToken();
    debugPrint("FCM Token: $token");
    if (token != null) {
      sl.webSocketSessionHandler.setFcmToken(token);
    }
  }

  Future<void> _handleMessageInteraction(RemoteMessage message) async {
    debugPrint('📬 Notification tapped: ${message.data}');

    // Give Firebase Auth time to reinitialize if app was terminated
    // This is critical because auth state may not be ready immediately
    await Future.delayed(const Duration(milliseconds: 500));

    // Ensure WebSocket is connected before handling notification
    final handler = sl.webSocketSessionHandler;
    final currentStatus = handler.connectionStatus;

    debugPrint('📊 Current connection status: $currentStatus');

    if (currentStatus != ConnectionStatus.connected) {
      debugPrint('🔌 Reconnecting WebSocket after notification tap...');
      try {
        final user = sl.authRepository.currentUser;
        if (user == null) {
          debugPrint('❌ No user found, cannot reconnect');
          return;
        }

        // ✅ FIX: Force token refresh in case it's expired after long background
        final token = await user.getIdToken(true);
        final displayName = user.displayName;

        if (token != null) {
          final serverUrl = AppConfig.instance.serverUrl;
          await handler.connect(serverUrl, token, displayName: displayName);
          debugPrint('✅ WebSocket reconnected successfully');
        } else {
          debugPrint('❌ Failed to get auth token');
        }
      } catch (e) {
        debugPrint('❌ Failed to reconnect WebSocket: $e');
        // Show error notification to user
        sl.notificationBloc.add(
          ShowErrorNotification('Failed to connect to server'),
        );
        return;
      }
    }

    // Handle specific notification types
    if (message.data.containsKey('type')) {
      final type = message.data['type'];
      if (type == 'game_invite') {
        // TODO: Navigate to lobby or join room
        final roomId = message.data['roomId'];
        debugPrint("Navigate to game invite for room: $roomId");
        // Future work: Add navigation after connection is established
      } else if (type == 'game_start') {
        debugPrint("Game started notification");
        // Future work: Navigate to active game
      } else if (type == 'game_end') {
        debugPrint("Game ended notification");
      }
    }
  }
}
