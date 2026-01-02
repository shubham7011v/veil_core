import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';

import 'features/session/state/session_provider.dart';
import 'features/session/ui/screens/session_screen.dart';
import 'features/session/ui/screens/lobby_screen.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/home/ui/home_screen.dart';
import 'features/lobby/ui/create_room_screen.dart';
import 'features/settings/ui/settings_screen.dart';
import 'features/rules/ui/rules_screen.dart';
import 'features/collection/ui/deck_collection_screen.dart';
import 'features/session/ui/screens/bot_settings_screen.dart';

void main() {
  runApp(const VeilApp());
}

class VeilApp extends StatelessWidget {
  const VeilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionProvider())],
      child: MaterialApp(
        title: 'Veil Core',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/login', // Start at Login
        routes: {
          '/login': (context) => const LoginScreen(),
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
    // For now, we read from provider or static mocks.
    final provider = context.watch<SessionProvider>();

    return LobbyScreen(
      roomId: provider.state.roomId,
      participants: provider.state.participants,
      onStart: () {
        provider.startSession();
        Navigator.pushReplacementNamed(context, '/session');
      },
    );
  }
}
