import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/notifications/bloc/app_notification_event.dart';

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

  void _handleMessageInteraction(RemoteMessage message) {
    if (message.data.containsKey('type')) {
      final type = message.data['type'];
      if (type == 'game_invite') {
        // Navigate to lobby or join room
        debugPrint("Navigate to game invite");
      }
    }
  }
}
