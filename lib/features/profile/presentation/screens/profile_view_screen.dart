import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../shared/components/app_error_widget.dart';
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../widgets/match_history_list.dart';

class ProfileViewScreen extends StatelessWidget {
  final String userId;

  const ProfileViewScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProfileBloc(repository: di.sl.profileRepository)
            ..add(ProfileViewRequested(userId)),
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          final palette = AppColors.getPalette(themeState.mode);

          return Scaffold(
            backgroundColor: palette.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: palette.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                if (state is ProfileLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: palette.primary),
                  );
                }

                if (state is ProfileError) {
                  return AppErrorWidget(
                    message: state.failure.message,
                    onRetry: () {
                      context.read<ProfileBloc>().add(
                        ProfileViewRequested(userId),
                      );
                    },
                  );
                }

                if (state is ProfileLoaded) {
                  return _buildProfileContent(context, state, palette);
                }

                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    ProfileLoaded state,
    AppColorPalette palette,
  ) {
    final profile = state.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar and Name
          CircleAvatar(
            radius: 60,
            backgroundColor: palette.primary.withValues(alpha: 0.1),
            backgroundImage: profile.photoUrl != null
                ? NetworkImage(profile.photoUrl!)
                : null,
            onBackgroundImageError: (exception, stackTrace) {
              // Silently handle error
            },
            child: profile.photoUrl == null
                ? Icon(Icons.person, size: 60, color: palette.primary)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            style: GoogleFonts.cinzel(
              color: palette.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Rank Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: palette.primaryDim,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              profile.stats.rank.toUpperCase(),
              style: GoogleFonts.inter(
                color: palette.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Online Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: profile.isOnline
                      ? palette.success
                      : palette.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                profile.isOnline ? 'ONLINE' : 'OFFLINE',
                style: GoogleFonts.inter(
                  color: profile.isOnline
                      ? palette.success
                      : palette.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Stats Grid
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'WINS',
                        '${profile.stats.wins}',
                        const Color(0xFF4CAF50),
                        palette,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem(
                        'LOSSES',
                        '${profile.stats.losses}',
                        palette.danger,
                        palette,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'GAMES',
                        '${profile.stats.gamesPlayed}',
                        Colors.blueAccent,
                        palette,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem(
                        'WIN RATE',
                        '${profile.stats.winRate.toStringAsFixed(1)}%',
                        palette.primary,
                        palette,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Match History (Only for own profile)
          if (state.isOwnProfile) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MATCH HISTORY',
                style: GoogleFonts.inter(
                  color: palette.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            MatchHistoryList(
              history: state.matchHistory,
              currentUserId: profile.userId,
            ),
          ],

          const SizedBox(height: 32),

          // Action Buttons
          if (!state.isOwnProfile) ...[
            if (!profile.isFriend)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<ProfileBloc>().add(ProfileFriendAdded(userId));
                    context.read<AppNotificationBloc>().add(
                      const ShowInfoNotification('Friend request sent'),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('ADD FRIEND'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: profile.isOnline
                      ? () {
                          context.read<AppNotificationBloc>().add(
                            const ShowInfoNotification(
                              'Challenge feature coming soon!',
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.sports_esports),
                  label: const Text('CHALLENGE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ProfileBloc>().add(
                      ProfileFriendRemoved(userId),
                    );
                    context.read<AppNotificationBloc>().add(
                      const ShowInfoNotification('Friend removed'),
                    );
                  },
                  icon: const Icon(Icons.person_remove),
                  label: const Text('REMOVE FRIEND'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.danger),
                    foregroundColor: palette.danger,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    AppColorPalette palette,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: palette.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cinzel(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
