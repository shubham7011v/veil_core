
import 'package:flutter/material.dart';
import 'colors.dart';
import '../constants/dimens.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      fontFamily: 'Inter', // Assumption: Using generic san-serif if font not loaded
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDim,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16, 
            fontWeight: FontWeight.w600
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
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
}
