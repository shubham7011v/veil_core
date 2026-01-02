import 'package:flutter/material.dart';

class Responsive {
  // Design reference dimensions (e.g. iPhone X/11 Pro)
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double _horizontalScale;
  static late double _verticalScale;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;

    _horizontalScale = screenWidth / _designWidth;
    _verticalScale = screenHeight / _designHeight;
  }

  // Width - scale horizontally
  static double w(double px) {
    return px * _horizontalScale;
  }

  // Height - scale vertically
  static double h(double px) {
    return px * _verticalScale;
  }

  // Sp (Font size) - scale based on width but clamped or limited?
  // Usually scale by width is safer for reading.
  static double sp(double px) {
    return px * _horizontalScale; // Simplified scaling
  }

  // Radius/Padding - usually width based
  static double r(double px) => w(px);

  // Percent width
  static double wp(double percent) => screenWidth * (percent / 100);

  // Percent height
  static double hp(double percent) => screenHeight * (percent / 100);

  static bool get isMobile => screenWidth < 600;
}
