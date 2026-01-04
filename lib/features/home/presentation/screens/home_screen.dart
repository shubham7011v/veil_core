import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../auth/auth.dart';
import '../../../profile/profile.dart';
import '../../../social/social.dart';
import '../../../collection/collection.dart';
import '../../../settings/settings.dart';
import '../widgets/royal_name_modal.dart';

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
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<ProfileBloc>().add(ProfileLoadRequested());
    }
  }

  void _goHome() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded && !state.user.isNameSet) {
          _showRoyalNameModal(context);
        }
      },
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
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading) {
          return Center(
            child: CircularProgressIndicator(color: palette.primary),
          );
        }

        final user = (state is ProfileLoaded) ? state.user : null;

        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final stats = (authState is Authenticated) ? authState.stats : null;

            return Column(
              children: [
                _buildTopBar(context, user, authState, palette),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Stats Grid (Embedded from Profile)
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
                                palette.danger, // Use theme danger color
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
                        const SizedBox(height: 24),
                        _buildPrivateRoomButton(context, palette),
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMatchCard(
                                context,
                                'FRIENDS\nMATCH',
                                Icons.people_outline,
                                () {},
                                palette,
                              ),
                            ),
                            const SizedBox(width: 16),
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
                        const SizedBox(height: 32),
                        _buildDailyChallenge(palette),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    dynamic user,
    AuthState authState,
    AppColorPalette palette,
  ) {
    String? photoUrl;
    String displayName = 'Mysterious Player';
    String rank = 'Novice';

    if (authState is Authenticated) {
      photoUrl = authState.user.photoURL;
      displayName = authState.user.displayName ?? displayName;
      rank = authState.stats?.rank ?? rank;
    } else if (user != null) {
      rank = user.rank;
    }

    // Only display the first name if a full name is provided
    if (displayName.contains(' ')) {
      displayName = displayName.split(' ').first;
    }

    String greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              // Non-tappable profile pic
              CircleAvatar(
                radius: 30,
                backgroundColor: palette.primary.withValues(alpha: 0.1),
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Icon(Icons.person, size: 20, color: palette.primary)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip('Rank', rank, palette.primary, palette),
              _buildInfoChip(
                'Coins',
                '${user?.coins ?? 1000}',
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
        Text(
          value,
          style: GoogleFonts.cinzel(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        color: palette.surfaceLight, // Use theme surface
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
                color: Colors.black, // Keep black text on high contrast primary
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
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, '/lobby'),
      child: Text(
        'Create or Join Private Room',
        style: GoogleFonts.inter(
          color: palette.textSecondary,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showRoyalNameModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RoyalNameModal(),
    );
  }
}
