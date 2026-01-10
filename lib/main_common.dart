import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_state.dart';
import 'core/theme/bloc/theme_event.dart';

import 'features/session/session.dart';
import 'features/auth/auth.dart';
import 'features/profile/profile.dart';
import 'features/challenges/presentation/bloc/challenges_bloc.dart';
import 'core/di/service_locator.dart' as di;
import 'core/navigation/app_router.dart';
import 'core/config/remote_config_service.dart';
import 'core/error/global_error_handler.dart';
import 'core/notifications/widgets/app_notification_listener.dart';
import 'shared/components/error_boundary.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'config/firebase_options_dev.dart' as dev;
import 'config/firebase_options_prod.dart' as prod;

Future<void> mainCommon({required String env, required String appName}) async {
  GlobalErrorHandler.run(() async {
    debugPrint('🚀 [STARTUP] Initializing $env environment...');

    // Bindings are initialized inside GlobalErrorHandler.run
    FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);

    // Initialize Core Configuration Singleton
    await AppConfig.initialize(env: env, appName: appName);
    final config = AppConfig.instance;

    final options =
        config.environment == 'production' || config.environment == 'prod'
        ? prod.DefaultFirebaseOptions.currentPlatform
        : dev.DefaultFirebaseOptions.currentPlatform;

    await Firebase.initializeApp(options: options);

    // Fully load config (now safe to access Remote Config)
    config.load();
    debugPrint('🚨 [DEBUG] STARTUP CONFIG CHECK 🚨');
    debugPrint('🚨 Server URL: ${config.serverUrl}');
    debugPrint('🚨 API URL: ${config.apiBaseUrl}');
    debugPrint('🚨 Environment: ${config.environment}');

    // Connectivity Doctor
    debugPrint('🚨 [DEBUG] Running Connectivity Check...');
    try {
      final request = await HttpClient()
          .getUrl(Uri.parse('${config.apiBaseUrl}/config'))
          .timeout(const Duration(seconds: 5));
      final response = await request.close();
      debugPrint('🚨 HTTP CONNECTIVITY CHECK: Status ${response.statusCode}');
      await response.drain();
    } catch (e) {
      debugPrint('🚨 HTTP CONNECTIVITY CHECK FAILED: $e');
    }

    // Initialize Remote Config Service
    await RemoteConfigService.instance.initialize();

    // Activate App Check
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: config.isDevelopment
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
      debugPrint('Firebase App Check activated');
    } catch (e) {
      debugPrint('Firebase App Check activation failed: $e');
    }

    // Initialize Service Locator
    await di.sl.setup();

    // Initialize Notifications
    try {
      await di.sl.notificationService.initialize();
    } catch (e) {
      debugPrint("Failed to initialize notifications: $e");
    }

    debugPrint('🚀 [STARTUP] runApp() called');
    runApp(const BluffApp());
  });
}

class BluffApp extends StatelessWidget {
  const BluffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl.notificationBloc),
        BlocProvider(create: (_) => ThemeBloc()..add(ThemeLoadRequested())),
        BlocProvider(
          create: (context) {
            final authBloc = AuthBloc(
              authRepository: di.sl.authRepository,
              userRepository: di.sl.userRepository,
              sessionRepository: di.sl.sessionRepository,
            )..add(AuthCheckRequested());
            di.sl.initializeSystemStatus(authBloc);
            return authBloc;
          },
        ),
        BlocProvider(
          create: (context) => ProfileBloc(repository: di.sl.profileRepository),
        ),
        BlocProvider(
          create: (context) =>
              ChallengesBloc(di.sl.challengesRepository)..add(LoadChallenges()),
        ),
        BlocProvider(create: (_) => SessionBloc()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Bluff',
            debugShowCheckedModeBanner: AppConfig.instance.isDevelopment,
            theme: AppTheme.getTheme(themeState.mode),
            initialRoute: AppRouter.splash,
            builder: (context, child) {
              return AppNotificationListener(
                child: ErrorBoundary(child: child!),
              );
            },
            routes: {
              ...AppRouter.routes,
              // LobbyScreen is now self-sufficient via Bloc
              // AppRouter.lobby is already handled in AppRouter.routes
            },
          );
        },
      ),
    );
  }
}

// Wrapper removed as LobbyScreen now handles its own state connection
