import 'app_config.dart';

/// Feature flags for enabling/disabling app features
class FeatureFlags {
  static AppConfig get _config => AppConfig.instance;

  /// Voice Chat Feature
  static bool get enableVoiceChat => _config.enableVoiceChat;

  /// Daily Challenges
  static bool get enableDailyChallenges => _config.enableDailyChallenges;

  /// Tournament Mode
  static bool get enableTournaments => _config.enableTournaments;

  /// Admin Dashboard
  static bool get enableAdminDashboard => _config.enableAdminDashboard;

  /// Private Rooms
  static bool get enablePrivateRooms => _config.enablePrivateRooms;

  /// Friends Match (Online via Server)
  static bool get enableFriendsMatch => _config.enableFriendsMatch;

  /// Friends Match (Offline/Local/Hotspot)
  static bool get enableFriendsMatchOffline =>
      _config.enableFriendsMatchOffline;

  /// Bot Players
  static bool get enableBotPlayers => _config.enableBotPlayers;

  /// Inner Circle (Social/Friends)
  static bool get enableInnerCircle => _config.enableInnerCircle;

  /// Global Rankings (Leaderboard)
  static bool get enableGlobalRankings => _config.enableGlobalRankings;

  /// Elite Deck Collection
  static bool get enableEliteDecks => _config.enableEliteDecks;

  /// Game Chat & Emoji
  static bool get enableGameChat => _config.enableGameChat;
}
