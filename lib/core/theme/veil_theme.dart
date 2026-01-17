import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central theme configuration for the Veil card game application.
///
/// This class provides consistent colors, text styles, and spacing throughout
/// the app to maintain a premium, cohesive user experience.
class VeilTheme {
  VeilTheme._(); // Private constructor to prevent instantiation

  // ==================== Colors ====================

  /// Primary brand color - gold accent used for highlights and key UI elements
  static const Color goldAccent = Color(0xFFE5A043);

  /// Dark background colors
  static const Color deepBlack = Color(0xFF0F0F0F);
  static const Color pureBlack = Colors.black;
  static const Color darkGray = Color(0xFF2C2C2C);

  /// Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textTertiary = Colors.white54;
  static const Color textQuaternary = Colors.white38;

  /// Semantic colors
  static const Color errorColor = Colors.redAccent;
  static const Color successColor = Colors.greenAccent;
  static const Color warningColor = Colors.orangeAccent;

  // ==================== Text Styles ====================

  /// Large title style for main headings (using Cinzel font)
  static TextStyle get titleLarge => GoogleFonts.cinzel(
    color: goldAccent,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  /// Medium title style for section headers
  static TextStyle get titleMedium => GoogleFonts.cinzel(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  /// Small title style for subsections
  static TextStyle get titleSmall => GoogleFonts.cinzel(
    color: goldAccent,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  /// Body text style for general content
  static TextStyle get bodyLarge =>
      GoogleFonts.inter(color: textPrimary, fontSize: 16, letterSpacing: 0.5);

  /// Secondary body text
  static TextStyle get bodyMedium =>
      GoogleFonts.inter(color: textSecondary, fontSize: 14);

  /// Small body text
  static TextStyle get bodySmall =>
      GoogleFonts.inter(color: textTertiary, fontSize: 12);

  /// Label text for buttons and chips
  static TextStyle get labelLarge => GoogleFonts.inter(
    color: goldAccent,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // ==================== Gradients ====================

  /// Background gradient for main screens
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepBlack, pureBlack],
  );

  /// Gold gradient for premium elements
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), goldAccent],
  );

  // ==================== Spacing ====================

  /// Extra small spacing (4px)
  static const double spacingXS = 4.0;

  /// Small spacing (8px)
  static const double spacingSM = 8.0;

  /// Medium spacing (16px)
  static const double spacingMD = 16.0;

  /// Large spacing (24px)
  static const double spacingLG = 24.0;

  /// Extra large spacing (32px)
  static const double spacingXL = 32.0;

  /// XXL spacing (48px)
  static const double spacingXXL = 48.0;

  // ==================== Border Radius ====================

  /// Small corner radius
  static const double radiusSM = 8.0;

  /// Medium corner radius
  static const double radiusMD = 12.0;

  /// Large corner radius
  static const double radiusLG = 16.0;

  /// Extra large corner radius
  static const double radiusXL = 24.0;

  // ==================== Common Padding ====================

  /// Standard horizontal padding for screens
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: spacingLG,
  );

  /// Standard vertical padding for screens
  static const EdgeInsets screenPaddingVertical = EdgeInsets.symmetric(
    vertical: spacingMD,
  );

  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(spacingMD);

  /// Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: spacingLG,
    vertical: spacingMD,
  );
}
