import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../auth/domain/models/user_stats.dart';
import '../../../../core/models/system_status.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import 'system_status_capsule.dart';

class HomeTopBar extends StatelessWidget {
  final User? user;
  final UserStats? stats;
  final AppColorPalette palette;
  final SystemStatus systemStatus;
  final String greeting;

  const HomeTopBar({
    super.key,
    this.user,
    this.stats,
    required this.palette,
    required this.systemStatus,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final String rawName =
        user?.displayName ?? stats?.name ?? 'Mysterious Player';
    final String displayName = rawName.split(' ').first;
    final String photoUrl = user?.photoURL ?? '';
    final String rank = stats?.rank ?? 'Novice';
    final int coins = stats?.coins ?? 1000;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'BLUFF',
                style: GoogleFonts.cinzel(
                  color: palette.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
              SystemStatusCapsule(systemStatus: systemStatus, palette: palette),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: palette.textTertiary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cinzel(
                        color: palette.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 30,
                backgroundColor: palette.primary.withValues(alpha: 0.1),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                onBackgroundImageError: (exception, stackTrace) {
                  // Silently handle the error
                  AppLogger.warning(
                    'Failed to load profile image',
                    exception: exception,
                  );
                },
                child: photoUrl.isEmpty
                    ? Icon(Icons.person, size: 20, color: palette.primary)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(context, 'Rank', rank, palette.primary, palette),
              // HIDDEN: Coin Balance for V1 Offline Release
              if (false)
                _buildInfoChip(
                  context,
                  'Coins',
                  coins.toString(),
                  palette.primary,
                  palette,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    String value,
    Color color,
    AppColorPalette palette,
  ) {
    // Only show refill button for Coins if value < 100
    final needsRefill =
        label == 'Coins' &&
        int.tryParse(value) != null &&
        int.parse(value) < 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: palette.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: GoogleFonts.cinzel(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (needsRefill)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () {
                    context.read<HomeBloc>().add(HomeRefillCoinsClicked());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.primaryDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'REFILL',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
