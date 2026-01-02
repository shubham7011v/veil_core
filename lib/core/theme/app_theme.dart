import 'package:flutter/material.dart';
import 'colors.dart';
import '../constants/dimens.dart';

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    final palette = AppColors.getPalette(mode);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.primary,
      fontFamily: 'Inter',

      colorScheme: ColorScheme.dark(
        primary: palette.primary,
        secondary: palette.primaryDim,
        surface: palette.surface,
        error: palette.danger,
        onPrimary: Colors.black,
        onSurface: palette.textPrimary,
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: palette.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: palette.textSecondary, fontSize: 14),
        labelLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingL,
            vertical: AppDimens.paddingM,
          ),
        ),
      ),
    );
  }

  // Legacy static access
  static ThemeData get darkTheme => getTheme(AppThemeMode.classic);
}
