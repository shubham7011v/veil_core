import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_state.dart';

import 'features/session/bloc/session_bloc.dart';
import 'features/session/bloc/session_event.dart';
import 'features/session/bloc/session_state.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/profile/repositories/user_repository.dart';
import 'features/profile/bloc/profile_bloc.dart';
import 'features/session/ui/screens/session_screen.dart';
import 'features/session/ui/screens/lobby_screen.dart';
import 'features/home/ui/home_screen.dart';
import 'features/lobby/ui/create_room_screen.dart';
import 'features/settings/ui/settings_screen.dart';
import 'features/rules/ui/rules_screen.dart';
import 'features/collection/ui/deck_collection_screen.dart';
import 'features/session/ui/screens/bot_settings_screen.dart';
import 'features/auth/ui/splash_screen.dart';
import 'features/auth/ui/intro_screen.dart';
import 'features/auth/ui/court_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/repositories/onboarding_repository.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'config/firebase_options_dev.dart' as dev;
import 'config/firebase_options_prod.dart' as prod;

Future<void> mainCommon(AppConfig config) async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final prefs = await SharedPreferences.getInstance();

  final options = config.environment == Environment.prod
      ? prod.DefaultFirebaseOptions.currentPlatform
      : dev.DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: options);

  // Activate App Check
  await FirebaseAppCheck.instance.activate(
    providerAndroid: config.environment == Environment.dev
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: const AppleDeviceCheckProvider(),
  );

  runApp(VeilApp(config: config, prefs: prefs));
}

class VeilApp extends StatelessWidget {
  final AppConfig config;
  final SharedPreferences prefs;
  const VeilApp({super.key, required this.config, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => UserRepository()),
        RepositoryProvider(create: (_) => OnboardingRepository(prefs)),
        RepositoryProvider.value(value: config),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeBloc()),
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
              userRepository: context.read<UserRepository>(),
            )..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (context) =>
                ProfileBloc(userRepository: context.read<UserRepository>()),
          ),
          BlocProvider(create: (_) => SessionBloc()),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            final themeProvider = AppTheme.getTheme(
              themeState.mode,
            ); // Helper logic if needed
            return MaterialApp(
              title: config.appName,
              debugShowCheckedModeBanner: config.isDev,
              theme: themeProvider,
              initialRoute: '/splash',
              routes: {
                '/splash': (context) => const SplashScreen(),
                '/intro': (context) => const IntroScreen(initialPage: 0),
                '/court_entry': (context) => const CourtEntryScreen(),
                '/home': (context) => const HomeScreen(),
                '/create_room': (context) => const CreateRoomScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/rules': (context) => const RulesScreen(),
                '/deck': (context) => const DeckCollectionScreen(),
                '/lobby': (context) =>
                    const LobbyWrapper(), // Wrapped to inject real data if needed
                '/session': (context) => const SessionScreen(),
                '/bot_settings': (context) => const BotSettingsScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

// Wrapper for Lobby to handle data passing logic if complex, or simple direct usage
class LobbyWrapper extends StatelessWidget {
  const LobbyWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // In a real app, arguments would be passed here.
    // For now, we read from bloc.
    return BlocBuilder<SessionBloc, SessionBlocState>(
      builder: (context, state) {
        return LobbyScreen(
          roomId: state.engineState.roomId,
          participants: state.engineState.participants,
          onStart: () {
            context.read<SessionBloc>().add(const SessionStartRequested());
            Navigator.pushReplacementNamed(context, '/session');
          },
        );
      },
    );
  }
}
