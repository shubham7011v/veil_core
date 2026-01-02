import 'package:flutter/material.dart';

class SessionBackground extends StatelessWidget {
  const SessionBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF2A1E17), Color(0xFF0D0D0D)],
          ),
        ),
      ),
    );
  }
}
