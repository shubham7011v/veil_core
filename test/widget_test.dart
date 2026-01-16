import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veil_core/main_common.dart';
import 'package:veil_core/core/config/app_config.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/features/auth/auth.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    await sl.setup();
    await AppConfig.initialize(env: 'development');

    // Build our app and trigger a frame.
    await tester.pumpWidget(const BluffApp());

    // Initially should show splash screen
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
