
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';

import 'features/session/models/session_state.dart';
import 'features/session/state/session_provider.dart';
import 'features/session/ui/screens/session_screen.dart';
import 'features/session/ui/screens/lobby_screen.dart';

void main() {
  runApp(const VeilApp());
}

class VeilApp extends StatelessWidget {
  const VeilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'Veil Core',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SessionWrapper(),
      ),
    );
  }
}

class SessionWrapper extends StatelessWidget {
  const SessionWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.select<SessionProvider, SessionPhase>((p) => p.state.currentPhase);
    
    if (phase == SessionPhase.lobby) {
      return const LobbyScreen();
    } else {
      return const SessionScreen();
    }
  }
}
