import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veil_core/config/app_config.dart';
import 'package:veil_core/main_common.dart';
import 'package:veil_core/features/auth/auth.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();

    final testConfig = AppConfig(
      environment: Environment.dev,
      appName: 'Veil Test',
      apiBaseUrl: 'https://test-api.veil.game',
      enableLogs: true,
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(VeilApp(config: testConfig));

    // Initially should show splash screen
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
