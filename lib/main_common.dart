import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/utils/app_logger.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_state.dart';
import 'core/theme/bloc/theme_event.dart';

import 'features/auth/auth.dart';
import 'features/profile/profile.dart';
import 'features/challenges/presentation/bloc/challenges_bloc.dart';
import 'core/di/service_locator.dart' as di;
import 'core/navigation/app_router.dart';

import 'core/error/global_error_handler.dart';
import 'core/error/failure.dart';
import 'core/notifications/widgets/app_notification_listener.dart';
import 'shared/components/error_boundary.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'config/firebase_options_dev.dart' as dev;
import 'config/firebase_options_prod.dart' as prod;

// Boot progress tracking for debugging production crashes
String _bootStep = 'Startup';
String get bootStep => _bootStep;
set bootStep(String value) => _bootStep = value;

Future<void> mainCommon({required String env, required String appName}) async {
  GlobalErrorHandler.run(() async {
    try {
      _bootStep = 'Initializing $env environment';
      AppLogger.info('🚀 [STARTUP] $_bootStep...');

      // Bindings are initialized inside GlobalErrorHandler.run
      FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);

      // Initialize Core Configuration Singleton
      _bootStep = '1. Initializing AppConfig';
      try {
        await AppConfig.initialize(env: env, appName: appName);
        AppLogger.info('🚀 [STARTUP] 1. AppConfig initialized');
      } catch (e) {
        throw 'AppConfig Initialization Failed: $e';
      }

      final config = AppConfig.instance;
      final options =
          config.environment == 'production' || config.environment == 'prod'
          ? prod.DefaultFirebaseOptions.currentPlatform
          : dev.DefaultFirebaseOptions.currentPlatform;

      _bootStep = '2. Initializing Firebase';
      AppLogger.info('🚀 [STARTUP] $_bootStep...');
      try {
        // Check if Firebase is already initialized to prevent duplicate-app error
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: options);
          AppLogger.info('🚀 [STARTUP] 2. Firebase initialized');
        } else {
          AppLogger.info(
            '🚀 [STARTUP] 2. Firebase already initialized, skipping',
          );
        }
      } on FirebaseException catch (e) {
        // Handle duplicate app error gracefully
        if (e.code == 'duplicate-app') {
          AppLogger.info(
            '🚀 [STARTUP] 2. Firebase app already exists, using existing instance',
          );
        } else {
          throw 'Firebase Initialization Failed: $e';
        }
      } catch (e) {
        throw 'Firebase Initialization Failed: $e';
      }

      // Fully load config
      _bootStep = '4. Loading Config';
      config.load();
      AppLogger.info('🚀 [STARTUP] 4. Config loaded');

      // Connectivity Doctor & Server Config Sync
      _bootStep = '5. Syncing Server Config';
      AppLogger.info('🚀 [STARTUP] $_bootStep...');
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final request = await client
            .getUrl(Uri.parse('${config.apiBaseUrl}/config'))
            .timeout(const Duration(seconds: 5));
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final serverData = json.decode(body) as Map<String, dynamic>;
          config.updateFromServer(serverData);
          AppLogger.info('🚀 [STARTUP] 5. Server Config Synced: $serverData');
        } else {
          AppLogger.info(
            '🚀 [STARTUP] 5. Server Config Fetch Failed: Status ${response.statusCode}',
          );
        }
      } catch (e) {
        AppLogger.info(
          '🚀 [STARTUP] 5. Server Config Sync Failed (continuing): $e',
        );
      }

      _bootStep = '6. Activating App Check';
      AppLogger.info('🚀 [STARTUP] $_bootStep...');
      try {
        // Only run App Check if Firebase is initialized
        if (Firebase.apps.isNotEmpty) {
          await FirebaseAppCheck.instance
              .activate(
                providerAndroid: config.isDevelopment
                    ? const AndroidDebugProvider()
                    : const AndroidPlayIntegrityProvider(),
                providerApple: const AppleDeviceCheckProvider(),
              )
              .timeout(const Duration(seconds: 5));
          AppLogger.info('🚀 [STARTUP] 6. App Check activated');
        }
      } catch (e) {
        // App Check failure can be fatal or non-fatal depending on security requirements.
        // For debugging, let's catch it but log clearly.
        AppLogger.info('🚀 [STARTUP] 6. App Check Failed (WARNING): $e');
      }

      // Initialize Service Locator
      _bootStep = '7. Setting up Service Locator';
      await di.sl.setup();
      AppLogger.info('🚀 [STARTUP] 7. Service Locator ready');

      // Initialize Notifications
      _bootStep = '8. Initializing Notifications';
      AppLogger.info('🚀 [STARTUP] $_bootStep...');
      try {
        await di.sl.notificationService.initialize().timeout(
          const Duration(seconds: 5),
        );
        AppLogger.info('🚀 [STARTUP] 8. Notifications initialized');
      } catch (e) {
        AppLogger.info(
          "🚀 [STARTUP] 8. Notification initialization failed (continuing): $e",
        );
      }

      _bootStep = '9. Running App';
      AppLogger.info('🚀 [STARTUP] runApp() called');
      runApp(const BluffApp());
    } catch (e, stack) {
      AppLogger.error(
        '🔥 CRITICAL STARTUP ERROR: $e',
        exception: e,
        stackTrace: stack,
      );

      // Report to Crashlytics if available and initialized
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
        }
      } catch (_) {
        // Ignore crash reporting failure if Firebase isn't ready
      }

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Last Step: $_bootStep',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
        BlocProvider.value(value: di.sl.sessionBloc),
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

    // 1. Handle Failure objects (important to check BEFORE obfuscation checks)
    if (err is Failure) {
      return err.message;
    }

    // 2. Explicitly Type-checked Errors
    if (err is PlatformException) {
      return 'Platform: ${err.code} - ${err.message}';
    }
    if (err is FirebaseException) {
      return 'Firebase: [${err.code}] ${err.message}';
    }
    if (err is StateError) return 'StateError: ${err.message}';
    if (err is TypeError) return 'TypeError: ${err.toString()}';
    if (err is ArgumentError) {
      return 'ArgError: ${err.message ?? err.toString()}';
    }
    if (err is FormatException) return 'FormatError: ${err.message}';

    // 3. Handle Obfuscated Classes (runtimeType might be "fta")
    final String typeName = error.runtimeType.toString();
    String str = error.toString();

    // If obfuscated (short name) or generic "Instance of", try to dig deeper
    if (str.startsWith('Instance of') || typeName.length <= 3) {
      try {
        final dynamic err = error;
        // Try accessing common properties dynamically
        final dynamic msg =
            err.message ?? err.failure ?? err.error ?? err.description;

        if (msg != null) {
          return '[$typeName]: $msg';
        }
      } catch (_) {}
    }

    // Default: truncate long strings

    if (str.length > 500) {
      str = '${str.substring(0, 500)}...';
    }

    return '[$typeName]: $str';
  } catch (_) {
    return 'Unknown Error Type: ${error.runtimeType}';
  }
}
