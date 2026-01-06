import 'package:flutter/material.dart';
import '../../features/session/session.dart';
import '../../features/home/home.dart';
import '../../features/lobby/lobby.dart';
import '../../features/settings/settings.dart';
import '../../features/rules/rules.dart';
import '../../features/collection/collection.dart';
import '../../features/auth/auth.dart';
import '../../features/matchmaking/matchmaking.dart';
import '../../features/social/social.dart';
import '../../features/lobby/presentation/screens/join_room_screen.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String intro = '/intro';
  static const String courtEntry = '/court_entry';
  static const String home = '/home';
  static const String createRoom = '/create_room';
  static const String joinRoom = '/join_room';
  static const String settings = '/settings';
  static const String rules = '/rules';
  static const String deck = '/deck';
  static const String lobby = '/lobby';
  static const String session = '/session';
  static const String botSettings = '/bot_settings';
  static const String matchmaking = '/matchmaking';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    intro: (context) => const IntroScreen(initialPage: 0),
    courtEntry: (context) => const CourtEntryScreen(),
    home: (context) => const HomeScreen(),
    createRoom: (context) => const CreateRoomScreen(),
    settings: (context) => const SettingsScreen(),
    rules: (context) => const RulesScreen(),
    deck: (context) => const DeckCollectionScreen(),
    lobby: (context) => const LobbyScreen(),
    session: (context) => const SessionScreen(),
    joinRoom: (context) => const JoinRoomScreen(),
    botSettings: (context) => const BotSettingsScreen(),
    matchmaking: (context) => const MatchmakingScreen(),
    '/leaderboard': (context) => const LeaderboardScreen(),
    '/friends': (context) => const FriendsScreen(),
  };
}
