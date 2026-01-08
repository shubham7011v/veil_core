import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'remote_config_service.dart';

/// Environment-based configuration management
///
/// Usage:
/// 1. Set environment variables before running:
///    flutter run --dart-define=ENV=production --dart-define=SERVER_URL=wss://your-server.com/ws
///
/// 2. Or use .env files with flutter_dotenv package
///
/// 3. Access config: AppConfig.instance.serverUrl
class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance => _instance ??= AppConfig._();

  AppConfig._() {
    _loadConfig();
  }

  // Environment
  late final String environment;
  late final bool isProduction;
  late final bool isDevelopment;

  // Server Configuration
  late final String serverUrl;
  late final String apiBaseUrl;

  // Reconnection Settings
  late final int maxReconnectAttempts;
  late final int reconnectBaseDelayMs;

  // Game Settings
  late final int defaultThinkingTimeS;
  late final int defaultPlayerCount;
  late final int maxPlayers;

  // Voice Settings
  late final int voiceTimeoutSeconds;
  late final int voiceSampleRate;

  // Rate Limiting
  late final int maxActionsPerSecond;

  // UI Settings
  late final int animationDurationMs;
  late final int cardDealDelayMs;

  // Development
  late final bool enableLogging;
  late final bool enableDebugMode;
  late final String? masterAdminId;

  // Legal & Support
  late final String privacyPolicyUrl;
  late final String termsUrl;
  late final String dataUsageUrl;
  late final String supportEmail;
  late final String gameRulesUrl;

  void _loadConfig() {
    // Load environment
    environment = const String.fromEnvironment(
      'ENV',
      defaultValue: 'development',
    );
    isProduction = environment == 'production';
    isDevelopment = environment == 'development';

    // Server Configuration
    if (isProduction) {
      serverUrl = const String.fromEnvironment(
        'SERVER_URL',
        defaultValue: 'wss://your-production-server.com/ws',
      );
      apiBaseUrl = const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://your-production-server.com/api',
      );
    } else {
      var defaultServerUrl = const String.fromEnvironment(
        'SERVER_URL',
        defaultValue: 'ws://localhost:8080/ws',
      );
      var defaultApiUrl = const String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://localhost:8080/api',
      );

      // Handle Android Emulator localhost (10.0.2.2)
      if (!kIsWeb && Platform.isAndroid) {
        if (defaultServerUrl.contains('localhost')) {
          defaultServerUrl = defaultServerUrl.replaceFirst(
            'localhost',
            '10.0.2.2',
          );
        }
        if (defaultApiUrl.contains('localhost')) {
          defaultApiUrl = defaultApiUrl.replaceFirst('localhost', '10.0.2.2');
        }
      }

      serverUrl = defaultServerUrl;
      apiBaseUrl = defaultApiUrl;
    }

    // Reconnection Settings
    maxReconnectAttempts = _getIntConfig(
      'max_reconnect_attempts',
      'MAX_RECONNECT_ATTEMPTS',
      5,
    );
    reconnectBaseDelayMs = _getIntConfig(
      'reconnect_base_delay_ms',
      'RECONNECT_BASE_DELAY_MS',
      2000,
    );

    // Game Settings
    defaultThinkingTimeS = _getIntConfig(
      'default_thinking_time_s',
      'DEFAULT_THINKING_TIME_S',
      10,
    );
    defaultPlayerCount = const int.fromEnvironment(
      'DEFAULT_PLAYER_COUNT',
      defaultValue: 5,
    );
    maxPlayers = _getIntConfig('max_players', 'MAX_PLAYERS', 8);

    // Voice Settings
    voiceTimeoutSeconds = _getIntConfig(
      'voice_timeout_seconds',
      'VOICE_TIMEOUT_SECONDS',
      30,
    );
    voiceSampleRate = const int.fromEnvironment(
      'VOICE_SAMPLE_RATE',
      defaultValue: 48000,
    );

    // Rate Limiting
    maxActionsPerSecond = _getIntConfig(
      'max_actions_per_second',
      'MAX_ACTIONS_PER_SECOND',
      10,
    );

    // UI Settings
    animationDurationMs = const int.fromEnvironment(
      'ANIMATION_DURATION_MS',
      defaultValue: 300,
    );
    cardDealDelayMs = const int.fromEnvironment(
      'CARD_DEAL_DELAY_MS',
      defaultValue: 100,
    );

    // Development
    enableLogging = const bool.fromEnvironment(
      'ENABLE_LOGGING',
      defaultValue: kDebugMode,
    );
    enableDebugMode = const bool.fromEnvironment(
      'DEBUG',
      defaultValue: kDebugMode,
    );

    masterAdminId = const String.fromEnvironment(
      'MASTER_ADMIN_ID',
      defaultValue:
          'ADMIN_UID_PLACEHOLDER', // Default to something safe or empty
    );

    // Legal & Support URLs
    privacyPolicyUrl = _getStringConfig(
      'privacy_policy_url',
      'PRIVACY_POLICY_URL',
      'https://example.com/privacy',
    );
    termsUrl = _getStringConfig(
      'terms_url',
      'TERMS_URL',
      'https://example.com/terms',
    );
    dataUsageUrl = _getStringConfig(
      'data_usage_url',
      'DATA_USAGE_URL',
      'https://example.com/data-usage',
    );
    supportEmail = _getStringConfig(
      'support_email',
      'SUPPORT_EMAIL',
      'support@example.com',
    );
    gameRulesUrl = _getStringConfig(
      'game_rules_url',
      'GAME_RULES_URL',
      'https://example.com/rules',
    );

    if (enableLogging) {
      _logConfig();
    }
  }

  void _logConfig() {
    debugPrint('=== AppConfig Loaded ===');
    debugPrint('Environment: $environment');
    debugPrint('Server URL: $serverUrl');
    debugPrint('API Base URL: $apiBaseUrl');
    debugPrint('Max Reconnect Attempts: $maxReconnectAttempts');
    debugPrint('Debug Mode: $enableDebugMode');
    debugPrint('=======================');
  }

  int _getIntConfig(String rcKey, String envKey, int defaultValue) {
    // 1. Try Remote Config
    final rcValue = RemoteConfigService.instance.getInt(rcKey);
    if (rcValue != 0) return rcValue;

    // 2. Try Environment Variable (Build Time)
    return int.fromEnvironment(envKey, defaultValue: defaultValue);
  }

  String _getStringConfig(String rcKey, String envKey, String defaultValue) {
    // 1. Try Remote Config
    final rcValue = RemoteConfigService.instance.getString(rcKey);
    if (rcValue.isNotEmpty) return rcValue;

    // 2. Try Environment Variable (Build Time)
    return String.fromEnvironment(envKey, defaultValue: defaultValue);
  }

  // Helper method to reload config (useful for testing)
  static void reload() {
    _instance = null;
    _instance = AppConfig._();
  }
}
