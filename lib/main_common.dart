import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_state.dart';
import 'core/theme/bloc/theme_event.dart';

import 'features/session/session.dart';
import 'features/auth/auth.dart';
import 'features/profile/profile.dart';
import 'core/di/service_locator.dart' as di;
import 'core/navigation/app_router.dart';
import 'core/config/remote_config_service.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'config/firebase_options_dev.dart' as dev;
import 'config/firebase_options_prod.dart' as prod;

Future<void> mainCommon(AppConfig config) async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final options = config.environment == Environment.prod
      ? prod.DefaultFirebaseOptions.currentPlatform
      : dev.DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: options);

  // Initialize Remote Config Service
  await RemoteConfigService.instance.initialize();

  // Activate App Check
  await FirebaseAppCheck.instance.activate(
    providerAndroid: config.environment == Environment.dev
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: const AppleDeviceCheckProvider(),
  );

  // Initialize Service Locator
  await di.sl.setup();

  runApp(VeilApp(config: config));
}

class VeilApp extends StatelessWidget {
  final AppConfig config;
  const VeilApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
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
        BlocProvider(create: (_) => SessionBloc()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: config.appName,
            debugShowCheckedModeBanner: config.isDev,
            theme: AppTheme.getTheme(themeState.mode),
            initialRoute: AppRouter.splash,
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
