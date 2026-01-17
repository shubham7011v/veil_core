import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/game_constants.dart';

class MatchmakingStatusView extends StatelessWidget {
  final bool isMatchFound;
  final int participantCount;
  final AppColorPalette palette;

  const MatchmakingStatusView({
    super.key,
    required this.isMatchFound,
    required this.participantCount,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isMatchFound ? 'Match Found!' : 'Looking for players...',
          style: GoogleFonts.inter(
            color: palette.textTertiary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Players found: $participantCount / ${GameConstants.maxPlayers}',
          style: GoogleFonts.cinzel(
            color: palette.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
