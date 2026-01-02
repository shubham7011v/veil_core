enum Environment { dev, prod }

class AppConfig {
  final Environment environment;
  final String appName;
  final String apiBaseUrl;
  final bool enableLogs;

  AppConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    this.enableLogs = false,
  });

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.prod;
}
