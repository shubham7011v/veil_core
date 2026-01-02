import 'package:shared_preferences/shared_preferences.dart';
import 'colors.dart';

class ThemeService {
  static const String _themeKey = 'user_theme_mode';

  static Future<void> saveTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  static Future<AppThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeKey);
    if (name == null) return AppThemeMode.classic;
    return AppThemeMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppThemeMode.classic,
    );
  }
}
