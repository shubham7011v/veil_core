import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:veil_core/core/utils/app_logger.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/notifications/bloc/app_notification_event.dart';
import 'package:veil_core/core/config/app_config.dart';
import 'package:veil_core/core/engine/domain/models/session_enums.dart';
import '../../features/session/session.dart';
import '../navigation/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `await Firebase.initializeApp()` here.
  AppLogger.info("Handling a background message: ${message.messageId}");
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
      AppLogger.info('User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      AppLogger.info('User granted provisional permission');
    } else {
      AppLogger.info('User declined or has not accepted permission');
      return;
    }

    // 2. Set Foreground Notification Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.info('Got a message whilst in the foreground!');
      AppLogger.info('Message data: ${message.data}');

      if (message.notification != null) {
        AppLogger.info(
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
      AppLogger.info('FCM Background Handler registered');
    }

    // 4. Handle notification tap when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.info('A new onMessageOpenedApp event was published!');
      _handleMessageInteraction(message);
    });

    // 5. Handle notification tap when app was terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageInteraction(initialMessage);
    }

    // 6. Get Token
    final token = await _fcm.getToken();
    AppLogger.info("FCM Token: $token");
    if (token != null) {
      sl.webSocketSessionHandler.setFcmToken(token);
    }
  }

  Future<void> _handleMessageInteraction(RemoteMessage message) async {
    AppLogger.info('📬 Notification tapped: ${message.data}');

    // Give Firebase Auth time to reinitialize if app was terminated
    // This is critical because auth state may not be ready immediately
    await Future.delayed(const Duration(milliseconds: 500));

    // Ensure WebSocket is connected before handling notification
    final handler = sl.webSocketSessionHandler;
    final currentStatus = handler.connectionStatus;

    AppLogger.info('📊 Current connection status: $currentStatus');

    if (currentStatus != ConnectionStatus.connected) {
      AppLogger.info('🔌 Reconnecting WebSocket after notification tap...');
      try {
        final user = sl.authRepository.currentUser;
        if (user == null) {
          AppLogger.info('❌ No user found, cannot reconnect');
          return;
        }

        // ✅ FIX: Force token refresh in case it's expired after long background
        final token = await user.getIdToken(true);
        final displayName = user.displayName;

        if (token != null) {
          final serverUrl = AppConfig.instance.serverUrl;
          await handler.connect(serverUrl, token, displayName: displayName);
          AppLogger.info('✅ WebSocket reconnected successfully');
        } else {
          AppLogger.info('❌ Failed to get auth token');
        }
      } catch (e) {
        AppLogger.error('❌ Failed to reconnect WebSocket', exception: e);
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
        final roomId = message.data['roomId'];
        AppLogger.info("Navigate to game invite for room: $roomId");

        // 1. Join the room on the handler
        handler.joinPrivateRoom(roomId);

        // 2. Ensure SessionBloc is using the WebSocket handler
        sl.sessionBloc.add(SessionHandlerSwapped(handler));

        // 3. Navigate to the lobby screen
        sl.navigationService.navigateTo(AppRouter.lobby);
      } else if (type == 'game_start') {
        AppLogger.info("Game started notification");
        // Ensure SessionBloc is using the WebSocket handler
        sl.sessionBloc.add(SessionHandlerSwapped(handler));
        // Navigate to the lobby (it will auto-redirect to session if game is active)
        sl.navigationService.navigateTo(AppRouter.lobby);
      } else if (type == 'game_end') {
        AppLogger.info("Game ended notification");
      }
    }
  }
}
