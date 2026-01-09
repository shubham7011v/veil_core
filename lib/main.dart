import 'config/app_config.dart';
import 'main_common.dart';

void main() {
  // Default to Dev config if run without target
  final defaultConfig = AppConfig(
    environment: Environment.dev,
    appName: 'Bluff Dev',
    enableLogs: true,
  );

  mainCommon(defaultConfig);
}
