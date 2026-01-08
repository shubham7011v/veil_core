import 'remote_config_service.dart';

/// Feature flags for enabling/disabling app features
class FeatureFlags {
  static final RemoteConfigService _rc = RemoteConfigService.instance;

  /// Voice Chat Feature
  static bool get enableVoiceChat => _rc.getBool('enable_voice_chat');

  /// Daily Challenges
  static bool get enableDailyChallenges =>
      _rc.getBool('enable_daily_challenges');

  /// Tournament Mode
  static bool get enableTournaments => _rc.getBool('enable_tournaments');

  /// Admin Dashboard
  static bool get enableAdminDashboard => _rc.getBool('enable_admin_dashboard');

  /// Private Rooms
  static bool get enablePrivateRooms => _rc.getBool('enable_private_rooms');

  /// Friends Match (Offline)
  static bool get enableFriendsMatch => _rc.getBool('enable_friends_match');

  /// Bot Players
  static const bool enableBotPlayers = true;
}
