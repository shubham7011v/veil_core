import 'package:flutter/material.dart';

class SessionBackground extends StatelessWidget {
  const SessionBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A), Colors.black],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
    );
  }
}
