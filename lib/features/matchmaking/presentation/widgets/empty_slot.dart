import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptySlot extends StatelessWidget {
  const EmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(width: 120, height: 160),

      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 2),
            ),
            child: Icon(
              Icons.person_outline,
              color: Colors.white.withValues(alpha: 0.2),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting...',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
