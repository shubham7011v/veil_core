import 'dart:io';
import 'dart:convert';
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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'config/firebase_options_dev.dart' as dev;
import 'config/firebase_options_prod.dart' as prod;

Future<void> mainCommon({required String env, required String appName}) async {
  GlobalErrorHandler.run(() async {
    try {
      debugPrint('🚀 [STARTUP] Initializing $env environment...');

      // Bindings are initialized inside GlobalErrorHandler.run
      FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);

      // Initialize Core Configuration Singleton
      debugPrint('🚀 [STARTUP] 1. Initializing AppConfig...');
      await AppConfig.initialize(env: env, appName: appName);
      final config = AppConfig.instance;
      debugPrint('🚀 [STARTUP] 1. AppConfig initialized');

      final options =
          config.environment == 'production' || config.environment == 'prod'
          ? prod.DefaultFirebaseOptions.currentPlatform
          : dev.DefaultFirebaseOptions.currentPlatform;

      debugPrint('🚀 [STARTUP] 2. Initializing Firebase...');
      await Firebase.initializeApp(options: options);
      debugPrint('🚀 [STARTUP] 2. Firebase initialized');

      // Initialize Remote Config Service (Fetch values from Firebase)
      debugPrint('🚀 [STARTUP] 3. Initializing Remote Config...');
      await RemoteConfigService.instance.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            debugPrint('🚀 [STARTUP] 3. Remote Config Timeout (continuing)'),
      );
      debugPrint('🚀 [STARTUP] 3. Remote Config initialized');

      // Fully load config (Now it can use fetched Remote Config values)
      config.load();
      debugPrint('🚀 [STARTUP] 4. Config loaded');
      // Connectivity Doctor & Server Config Sync
      debugPrint('🚀 [STARTUP] 5. Syncing Server Config...');
      try {
        final client = HttpClient();
        final request = await client
            .getUrl(Uri.parse('${config.apiBaseUrl}/config'))
            .timeout(const Duration(seconds: 4)); // Reduced timeout
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final serverData = json.decode(body) as Map<String, dynamic>;
          config.updateFromServer(serverData);
          debugPrint('🚀 [STARTUP] 5. Server Config Synced: $serverData');
        } else {
          debugPrint(
            '🚀 [STARTUP] 5. Server Config Fetch Failed: Status ${response.statusCode}',
          );
        }
      } catch (e) {
        debugPrint(
          '🚀 [STARTUP] 5. Server Config Sync Failed (continuing): $e',
        );
      }
      debugPrint('🚀 [STARTUP] 6. Activating App Check...');
      try {
        await FirebaseAppCheck.instance
            .activate(
              providerAndroid: config.isDevelopment
                  ? const AndroidDebugProvider()
                  : const AndroidPlayIntegrityProvider(),
              providerApple: const AppleDeviceCheckProvider(),
            )
            .timeout(const Duration(seconds: 5));
        debugPrint('🚀 [STARTUP] 6. App Check activated');
      } catch (e) {
        debugPrint(
          '🚀 [STARTUP] 6. App Check activation failed (continuing): $e',
        );
      }

      // Initialize Service Locator
      debugPrint('🚀 [STARTUP] 7. Setting up Service Locator...');
      await di.sl.setup();
      debugPrint('🚀 [STARTUP] 7. Service Locator ready');

      // Initialize Notifications
      debugPrint('🚀 [STARTUP] 8. Initializing Notifications...');
      try {
        await di.sl.notificationService.initialize().timeout(
          const Duration(seconds: 5),
        );
        debugPrint('🚀 [STARTUP] 8. Notifications initialized');
      } catch (e) {
        debugPrint(
          "🚀 [STARTUP] 8. Notification initialization failed (continuing): $e",
        );
      }

      debugPrint('🚀 [STARTUP] runApp() called');
      runApp(const BluffApp());
    } catch (e, stack) {
      debugPrint('🔥 CRITICAL STARTUP ERROR: $e');
      debugPrintStack(stackTrace: stack);

      // Report to Crashlytics if available
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
        }
      } catch (_) {}

      FlutterNativeSplash.remove(); // Force remove splash to show error
      runApp(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.red.shade900,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Startup Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _getErrorMessage(e),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SelectableText(
                      stack.toString(),
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
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

/// Extracts a meaningful error message from any error object
String _getErrorMessage(Object error) {
  // Try to extract message property if it exists
  try {
    final dynamic err = error;
    if (err is StateError) return err.message;
    if (err is TypeError) return err.toString();
    if (err is ArgumentError) return err.message ?? err.toString();
    if (err is FormatException) return err.message;

    // Try to access message property via reflection
    if (err.toString().startsWith('Instance of')) {
      // For custom errors, try common property names
      try {
        return (err as dynamic).message?.toString() ??
            (err as dynamic).description?.toString() ??
            error.runtimeType.toString();
      } catch (_) {
        return error.runtimeType.toString();
      }
    }

    return error.toString();
  } catch (_) {
    return error.runtimeType.toString();
  }
}
