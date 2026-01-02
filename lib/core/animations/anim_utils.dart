
import 'package:flutter/material.dart';

class AnimUtils {
  // Durations
  static const Duration micro = Duration(milliseconds: 150); // Taps, small feedback
  static const Duration fast = Duration(milliseconds: 300); // Participant join, simple fades
  static const Duration medium = Duration(milliseconds: 600); // Movement, Deal
  static const Duration visual = Duration(milliseconds: 800); // Dramatic reveals
  static const Duration breathing = Duration(seconds: 3); // Idle loop

  // Curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeOutBack = Curves.easeOutBack; // For bounces/arrivals
  static const Curve easeInOut = Curves.easeInOut; // For transitions
  static const Curve elasticOut = Curves.elasticOut; // Occasional punchy effect
  
  // Transitions
  static Widget slideUpFade({
    required Animation<double> animation, 
    required Widget child, 
    double offset = 0.05
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, offset),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
