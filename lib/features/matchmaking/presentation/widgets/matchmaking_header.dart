import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';

class MatchmakingHeader extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback onClose;
  final AppColorPalette palette;
  final Animation<double> pulseAnimation;

  const MatchmakingHeader({
    super.key,
    required this.secondsRemaining,
    required this.onClose,
    required this.palette,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: pulseAnimation, curve: Curves.easeInOut),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finding a Match',
                  style: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starting in: $secondsRemaining seconds',
                  style: GoogleFonts.cinzel(
                    color: secondsRemaining <= 10
                        ? palette.danger
                        : palette.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.close, color: palette.textTertiary),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
