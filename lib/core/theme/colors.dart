import 'package:flutter/material.dart';

enum AppThemeMode { classic, midnight, neon, ocean }

class AppColorPalette {
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color primary;
  final Color primaryDim;
  final Color activeGlow;
  final Color warn;
  final Color danger;
  final Color success;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color cardBack;
  final Color divider;

  const AppColorPalette({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.primary,
    required this.primaryDim,
    required this.activeGlow,
    this.warn = const Color(0xFFFFC107), // Default Amber
    required this.danger,
    required this.success,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.cardBack,
    required this.divider,
  });
}

class AppColors {
  static AppColorPalette getPalette(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.midnight:
        return const AppColorPalette(
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
          surfaceLight: Color(0xFF334155),
          primary: Color(0xFF38BDF8),
          primaryDim: Color(0xFF0369A1),
          activeGlow: Color(0x6638BDF8),
          warn: Color(0xFFF59E0B),
          danger: Color(0xFFF43F5E),
          success: Color(0xFF10B981),
          textPrimary: Color(0xFFF1F5F9),
          textSecondary: Color(0xFF94A3B8),
          textTertiary: Color(0xFF64748B),
          cardBack: Color(0xFF1E293B),
          divider: Color(0xFF334155),
        );
      case AppThemeMode.neon:
        return const AppColorPalette(
          background: Color(0xFF000000),
          surface: Color(0xFF111111),
          surfaceLight: Color(0xFF222222),
          primary: Color(0xFF39FF14),
          primaryDim: Color(0xFF1D800A),
          activeGlow: Color(0x6639FF14),
          warn: Color(0xFFFFD600),
          danger: Color(0xFFFF003C),
          success: Color(0xFF00FFCC),
          textPrimary: Color(0xFFFFFFFF),
          textSecondary: Color(0xFFBBBBBB),
          textTertiary: Color(0xFF888888),
          cardBack: Color(0xFF111111),
          divider: Color(0xFF333333),
        );
      case AppThemeMode.ocean:
        return const AppColorPalette(
          background: Color(0xFF001F24),
          surface: Color(0xFF00363D),
          surfaceLight: Color(0xFF004D56),
          primary: Color(0xFF26C6DA),
          primaryDim: Color(0xFF0097A7),
          activeGlow: Color(0x6626C6DA),
          warn: Color(0xFFFFCA28),
          danger: Color(0xFFFF5252),
          success: Color(0xFF00E676),
          textPrimary: Color(0xFFE0F7FA),
          textSecondary: Color(0xFF80DEEA),
          textTertiary: Color(0xFF4DD0E1),
          cardBack: Color(0xFF00363D),
          divider: Color(0xFF005A64),
        );
      case AppThemeMode.classic:
        return const AppColorPalette(
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          surfaceLight: Color(0xFF2C2C2C),
          primary: Color(0xFFE5A043),
          primaryDim: Color(0xFF8F632A),
          activeGlow: Color(0x66E5A043),
          warn: Color(0xFFFFC107),
          danger: Color(0xFFCF6679),
          success: Color(0xFF4CAF50),
          textPrimary: Color(0xFFEEEEEE),
          textSecondary: Color(0xFFAAAAAA),
          textTertiary: Color(0xFF666666),
          cardBack: Color(0xFF2A2A2A),
          divider: Color(0xFF333333),
        );
    }
  }

  // Backward compatibility for existing static access if needed during migration
  // but we prefer using current palette from provider.
  // Legacy statics (pointing to classic)
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2C2C2C);
  static const Color primary = Color(0xFFE5A043);
  static const Color primaryDim = Color(0xFF8F632A);
  static const Color activeGlow = Color(0x66E5A043);
  static const Color danger = Color(0xFFCF6679);
  static const Color success = Color(0xFF4CAF50);
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF666666);
  static const Color cardBack = Color(0xFF2A2A2A);
  static const Color divider = Color(0xFF333333);
}
