import 'config/app_config.dart';
import 'main_common.dart';

void main() {
  final prodConfig = AppConfig(
    environment: Environment.prod,
    appName: 'Bluff',
    apiBaseUrl: 'https://api.veil.game', // Placeholder
    enableLogs: false,
  );

  mainCommon(prodConfig);
}
