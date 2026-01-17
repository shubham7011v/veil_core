import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';
import '../../../auth/domain/models/user_stats.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';

class HomePlayOnlineCard extends StatelessWidget {
  final AppColorPalette palette;
  final UserStats? stats;
  final bool hasActiveSession;

  const HomePlayOnlineCard({
    super.key,
    required this.palette,
    this.stats,
    required this.hasActiveSession,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasActiveSession)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: palette.warn.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.warn),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: palette.warn,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'GAME IN PROGRESS',
                  style: GoogleFonts.inter(
                    color: palette.warn,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.primary.withValues(alpha: 0.9),
                palette.primaryDim.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.read<HomeBloc>().add(HomePlayOnlineClicked(stats));
              },
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasActiveSession ? 'RESUME GAME' : 'PLAY ONLINE',
                      style: GoogleFonts.cinzel(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    if (hasActiveSession)
                      Text(
                        'Tap to rejoin',
                        style: GoogleFonts.inter(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        'Entry: 100 Coins',
                        style: GoogleFonts.inter(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
