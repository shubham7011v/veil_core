import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../utils/app_logger.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._();
  static RemoteConfigService get instance => _instance;

  // Lazy initialization to avoid NotInitializedError before Firebase.initializeApp()
  FirebaseRemoteConfig? _remoteConfigInstance;
  FirebaseRemoteConfig get _remoteConfig {
    _remoteConfigInstance ??= FirebaseRemoteConfig.instance;
    return _remoteConfigInstance!;
  }

  RemoteConfigService._();

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set defaults for game balancing
      await _remoteConfig.setDefaults({
        'default_thinking_time_s': 10,
        'max_players': 10,
        'reconnect_base_delay_ms': 2000,
        'max_reconnect_attempts': 5,
        'voice_timeout_seconds': 30,
        'max_actions_per_second': 10,
        // Feature Flags
        'enable_voice_chat': false,
        'enable_daily_challenges': false,
        'enable_tournaments': false,
        'enable_admin_dashboard':
            true, // Enabling by default since we implemented it
        'enable_private_rooms': false,
        'enable_friends_match': false,
        'enable_friends_match_offline': false,
        'enable_bot_players': false,
        'enable_inner_circle': false,
        'enable_global_rankings': false,
        'enable_elite_decks': false,
        'admin_uids': '', // Comma-separated UIDs
      });

      await fetchAndActivate();
    } catch (e) {
      AppLogger.error('Failed to initialize Remote Config', exception: e);
    }
  }

  Future<void> fetchAndActivate() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      if (updated) {
        AppLogger.info('Remote Config updated and activated');
      } else {
        AppLogger.info('Remote Config fetch completed, no new updates');
      }
    } catch (e) {
      AppLogger.error('Failed to fetch Remote Config', exception: e);
    }
  }

  int getInt(String key) => _remoteConfig.getInt(key);
  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);
}
