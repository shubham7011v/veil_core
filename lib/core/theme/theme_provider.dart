import 'package:flutter/material.dart';
import 'colors.dart';
import 'app_theme.dart';
import 'theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.classic;
  bool _isLoaded = false;

  ThemeProvider() {
    _init();
  }

  AppThemeMode get mode => _mode;
  bool get isLoaded => _isLoaded;
  AppColorPalette get palette => AppColors.getPalette(_mode);
  ThemeData get themeData => AppTheme.getTheme(_mode);

  Future<void> _init() async {
    _mode = await ThemeService.loadTheme();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    await ThemeService.saveTheme(newMode);
  }
}
