enum Environment { dev, prod }

class AppConfig {
  final Environment environment;
  final String appName;
  final String apiBaseUrl;
  final bool enableLogs;

  AppConfig({
    required this.environment,
    required this.appName,
    String? apiBaseUrl,
    this.enableLogs = false,
  }) : apiBaseUrl =
           apiBaseUrl ??
           const String.fromEnvironment(
             'API_URL',
             defaultValue: 'https://api.veil.game',
           );

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.prod;
}
