import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/session_constants.dart';

/// Manages turn feedback popups that appear above the staging area
/// Extracted from session_screen.dart to improve separation of concerns
class TurnPopupManager {
  final void Function(VoidCallback fn) setState;

  String? _turnPopupText;
  Color _turnPopupColor = const Color(0xFFFFD700); // Default Gold
  Timer? _turnPopupTimer;

  TurnPopupManager({required this.setState});

  // Getters for UI
  String? get popupText => _turnPopupText;
  Color get popupColor => _turnPopupColor;

  /// Show a turn popup with custom text and color
  void showPopup(String text, [Color color = const Color(0xFFFFD700)]) {
    _turnPopupTimer?.cancel();
    setState(() {
      _turnPopupText = text;
      _turnPopupColor = color;
    });
    _turnPopupTimer = Timer(SessionDurations.turnPopupDuration, () {
      setState(() {
        _turnPopupText = null;
      });
    });
  }

  /// Build the popup widget (if visible)
  Widget? buildPopup() {
    if (_turnPopupText == null) return null;

    return Container(
      height: 120, // Approximate height of staging area
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(
              opacity: value,
              child: Container(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _turnPopupColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _turnPopupColor.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _turnPopupText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _turnPopupColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: _turnPopupColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Clean up resources
  void dispose() {
    _turnPopupTimer?.cancel();
  }
}
