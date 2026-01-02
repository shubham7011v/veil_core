import 'config/app_config.dart';
import 'main_common.dart';

void main() {
  final devConfig = AppConfig(
    environment: Environment.dev,
    appName: 'Bluffdev',
    apiBaseUrl: 'https://dev-api.veil.game', // Placeholder
    enableLogs: true,
  );

  mainCommon(devConfig);
}
