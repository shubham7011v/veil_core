import 'config/app_config.dart';
import 'main_common.dart';

void main() {
  // Default to Dev config if run without target
  final defaultConfig = AppConfig(
    environment: Environment.dev,
    appName: 'Veil Dev',
    apiBaseUrl: 'https://dev-api.veil.game',
    enableLogs: true,
  );

  mainCommon(defaultConfig);
}
