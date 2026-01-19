import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../auth/auth.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import 'home_top_bar.dart';
import 'home_stat_item.dart';
import 'home_play_online_card.dart';
import 'home_private_room_section.dart';
import 'home_match_card.dart';
import 'home_daily_challenge_card.dart';
import 'home_premium_button.dart';

class HomeDashboard extends StatelessWidget {
  final AppColorPalette palette;
  final HomeState homeState;

  const HomeDashboard({
    super.key,
    required this.palette,
    required this.homeState,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final stats = (authState is Authenticated) ? authState.stats : null;
        final user = (authState is Authenticated) ? authState.user : null;

        return Column(
          children: [
            HomeTopBar(
              user: user,
              stats: stats,
              palette: palette,
              systemStatus: homeState.systemStatus,
              greeting: homeState.greeting,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // HIDDEN: Stats Grid, Online Play, Private Room for V1 Offline Release
                    if (false) ...[
                      // Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: HomeStatItem(
                              label: 'Wins',
                              value: '${stats?.wins ?? 0}',
                              color: const Color(0xFF4CAF50),
                              palette: palette,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: HomeStatItem(
                              label: 'Losses',
                              value: '${stats?.losses ?? 0}',
                              color: palette.danger,
                              palette: palette,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: HomeStatItem(
                              label: 'Total Games',
                              value: '${stats?.gamesPlayed ?? 0}',
                              color: Colors.blueAccent,
                              palette: palette,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: HomeStatItem(
                              label: 'Win Rate',
                              value:
                                  '${stats?.winRate.toStringAsFixed(1) ?? '0.0'}%',
                              color: palette.primary,
                              palette: palette,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      HomePlayOnlineCard(
                        palette: palette,
                        stats: stats,
                        hasActiveSession: homeState.hasActiveSession,
                      ),
                    ],

                    // V1 Offline Focus: Big Play Button
                    HomePremiumButton(
                      palette: palette,
                      title: 'PLAY',
                      subtitle:
                          'FIND MATCH', // Or 'FIND MATCH' to be more like online? Let's stick to user request "play button".
                      icon: Icons.play_arrow_rounded,
                      onTap: () =>
                          context.read<HomeBloc>().add(HomeBotMatchClicked()),
                    ),

                    const SizedBox(height: 32),
                    HomePrivateRoomSection(palette: palette),

                    if (false) ...[
                      Row(
                        children: [
                          Expanded(
                            child: HomeMatchCard(
                              title: 'FRIENDS\nMATCH',
                              icon: Icons.people_outline,
                              onTap: () => context.read<HomeBloc>().add(
                                HomeFriendsMatchClicked(),
                              ),
                              palette: palette,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: HomeMatchCard(
                              title: 'BOT\nMATCH',
                              icon: Icons.smart_toy_outlined,
                              onTap: () => context.read<HomeBloc>().add(
                                HomeBotMatchClicked(),
                              ),
                              palette: palette,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (false) ...[
                      const SizedBox(height: 32),
                      HomeDailyChallengeCard(palette: palette),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
