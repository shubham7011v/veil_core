import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/notifications/widgets/app_notification_listener.dart';
import '../../../../core/constants/sound_assets.dart';
import '../../../../core/di/service_locator.dart';
import '../../../auth/auth.dart';
import '../../../social/social.dart';
import '../../../collection/collection.dart';
import '../../../settings/settings.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/coming_soon_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start lobby music after successful auth
    _startLobbyMusic();
  }

  void _startLobbyMusic() {
    // Delay slightly to ensure audio service is fully initialized
    // TODO: Replace this hardcoded delay with a proper 'isInitialized' check from AudioService
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        sl.audioService.playBgm(SoundAssets.lobbyAmbience);
      }
    });
  }

  void _goHome() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppNotificationListener(
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          final palette = AppColors.getPalette(themeState.mode);

          return PopScope(
            canPop: _selectedIndex == 0,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _goHome();
            },
            child: Scaffold(
              backgroundColor: palette.background,
              body: SafeArea(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildHomeDashboard(palette),
                    FriendsScreen(onBack: _goHome),
                    LeaderboardScreen(onBack: _goHome),
                    DeckCollectionScreen(onBack: _goHome),
                    SettingsScreen(onBack: _goHome),
                  ],
                ),
              ),
              bottomNavigationBar: _buildBottomNav(palette),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeDashboard(AppColorPalette palette) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final stats = (authState is Authenticated) ? authState.stats : null;
        final user = (authState is Authenticated) ? authState.user : null;

        return Column(
          children: [
            HomeTopBar(user: user, stats: stats, palette: palette),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Wins',
                            '${stats?.wins ?? 0}',
                            const Color(0xFF4CAF50),
                            palette,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            'Losses',
                            '${stats?.losses ?? 0}',
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
                            'Total Games',
                            '${stats?.gamesPlayed ?? 0}',
                            Colors.blueAccent,
                            palette,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            'Win Rate',
                            '${stats?.winRate.toStringAsFixed(1) ?? '0.0'}%',
                            palette.primary,
                            palette,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                    _buildPlayOnlineCTA(context, palette),
                    if (FeatureFlags.enablePrivateRooms) ...[
                      const SizedBox(height: 24),
                      _buildPrivateRoomButton(context, palette),
                    ],
                    if (FeatureFlags.enableFriendsMatch ||
                        FeatureFlags.enableBotPlayers) ...[
                      const SizedBox(height: 48),
                      Row(
                        children: [
                          if (FeatureFlags.enableFriendsMatch ||
                              FeatureFlags.enableFriendsMatchOffline)
                            Expanded(
                              child: _buildMatchCard(
                                context,
                                FeatureFlags.enableFriendsMatchOffline
                                    ? 'FRIENDS\nMATCH (OFFLINE)'
                                    : 'FRIENDS\nMATCH',
                                FeatureFlags.enableFriendsMatchOffline
                                    ? Icons.wifi_tethering
                                    : Icons.people_outline,
                                () {
                                  if (FeatureFlags.enableFriendsMatchOffline) {
                                    Navigator.pushNamed(
                                      context,
                                      AppRouter.offlineLobby,
                                    );
                                  } else {
                                    _showComingSoonModal(context, palette);
                                  }
                                },
                                palette,
                              ),
                            ),
                          if (FeatureFlags.enableFriendsMatch &&
                              FeatureFlags.enableBotPlayers)
                            const SizedBox(width: 16),
                          if (FeatureFlags.enableBotPlayers)
                            Expanded(
                              child: _buildMatchCard(
                                context,
                                'BOT\nMATCH',
                                Icons.smart_toy_outlined,
                                () => Navigator.pushNamed(
                                  context,
                                  '/bot_settings',
                                ),
                                palette,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (FeatureFlags.enableDailyChallenges) ...[
                      const SizedBox(height: 32),
                      _buildDailyChallenge(palette),
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

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    AppColorPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: palette.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cinzel(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayOnlineCTA(BuildContext context, AppColorPalette palette) {
    return Container(
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
          onTap: () => Navigator.pushNamed(context, '/matchmaking'),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              'PLAY ONLINE',
              style: GoogleFonts.cinzel(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateRoomButton(
    BuildContext context,
    AppColorPalette palette,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMatchCard(
            context,
            'CREATE\nROOM',
            Icons.add_circle_outline,
            () => Navigator.pushNamed(context, '/create_room'),
            palette,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMatchCard(
            context,
            'JOIN\nROOM',
            Icons.login,
            () => Navigator.pushNamed(context, '/join_room'),
            palette,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    AppColorPalette palette,
  ) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: palette.primary, size: 32),
                Text(
                  title,
                  style: GoogleFonts.cinzel(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyChallenge(AppColorPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/challenges');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.track_changes, color: palette.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Daily Challenge',
                  style: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(AppColorPalette palette) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      backgroundColor: palette.background,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: palette.primary,
      unselectedItemColor: palette.textTertiary,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: ''),
        BottomNavigationBarItem(
          icon: Icon(Icons.emoji_events_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_outlined),
          label: '',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: ''),
      ],
    );
  }

  void _showComingSoonModal(BuildContext context, AppColorPalette palette) {
    showDialog(
      context: context,
      builder: (context) => ComingSoonModal(
        featureName: 'Offline Hotspot Mode',
        description:
            'Challenge your friends in person! Create a local hotspot and play together without an internet connection.',
        icon: Icons.wifi_tethering_rounded,
        palette: palette,
        featureHighlights: const [
          {
            'icon': Icons.wifi_tethering_rounded,
            'text': 'Offline Hotspot Mode',
          },
          {'icon': Icons.devices_rounded, 'text': 'Local Network Play'},
          {'icon': Icons.group_rounded, 'text': 'Connect with Nearby Friends'},
        ],
      ),
    );
  }
}
