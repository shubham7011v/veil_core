import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../auth/domain/models/user_stats.dart';
import '../../../../core/models/system_status.dart';

class HomeTopBar extends StatelessWidget {
  final User? user;
  final UserStats? stats;
  final AppColorPalette palette;

  const HomeTopBar({super.key, this.user, this.stats, required this.palette});

  @override
  Widget build(BuildContext context) {
    final String greeting = sl.greetingService.getTimeBasedGreeting();
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
              _buildSystemStatusCapsule(context),
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
                  // debugPrint('Failed to load profile image: $exception');
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
            if (label == 'Coins' &&
                int.tryParse(value) != null &&
                int.parse(value) < 100)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () {
                    sl.webSocketSessionHandler.refillCoins();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refilling coins...')),
                    );
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

  Widget _buildSystemStatusCapsule(BuildContext context) {
    return StreamBuilder<SystemStatus>(
      stream: sl.systemStatusService.statusStream,
      initialData: sl.systemStatusService.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? sl.systemStatusService.currentStatus;
        return GestureDetector(
          onTap: () => _showDiagnosticsModal(context, status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status.statusColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: status.statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: status.statusColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(height: 10, width: 1, color: palette.divider),
                const SizedBox(width: 8),
                Icon(status.icon, size: 12, color: status.statusColor),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDiagnosticsModal(BuildContext context, SystemStatus status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(status.icon, color: status.statusColor, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    status.label.toUpperCase(),
                    style: GoogleFonts.cinzel(
                      color: status.statusColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                status.description,
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    status.actionLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
