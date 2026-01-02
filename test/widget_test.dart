// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:veil_core/config/app_config.dart';
import 'package:veil_core/main_common.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    final testConfig = AppConfig(
      environment: Environment.dev,
      appName: 'Veil Test',
      apiBaseUrl: 'https://test-api.veil.game',
      enableLogs: true,
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(VeilApp(config: testConfig));

    // Verify that the login screen is displayed.
    expect(find.text('Welcome to the\nRoyal Court'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
