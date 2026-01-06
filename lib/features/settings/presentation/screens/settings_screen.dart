import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/theme/bloc/theme_event.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/dimens.dart';
import '../../../auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _masterVolume = 75;
  bool _music = true;
  bool _sfx = true;
  bool _haptics = true;
  bool _notifications = false;
  bool _showAvatars = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            title: const Text(
              'SETTINGS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: palette.textSecondary),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.paddingM),
              children: [
                const _SectionHeader('AUDIO'),
                Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                  ),
                  padding: const EdgeInsets.all(AppDimens.paddingM),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.volume_up, color: palette.primary),
                          const SizedBox(width: AppDimens.paddingM),
                          Text(
                            'Master Volume',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_masterVolume.toInt()}%',
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: palette.primary,
                          inactiveTrackColor: palette.surface,
                          thumbColor: palette.primary,
                        ),
                        child: Slider(
                          value: _masterVolume,
                          min: 0,
                          max: 100,
                          onChanged: (v) => setState(() => _masterVolume = v),
                        ),
                      ),
                      Divider(color: palette.divider),
                      _buildSwitchTile(
                        palette,
                        Icons.music_note,
                        'Music',
                        'Background score',
                        _music,
                        (v) => setState(() => _music = v),
                      ),
                      Divider(color: palette.divider),
                      _buildSwitchTile(
                        palette,
                        Icons.graphic_eq,
                        'Sound Effects',
                        'Chips & cards sounds',
                        _sfx,
                        (v) => setState(() => _sfx = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                const _SectionHeader('GAMEPLAY'),
                Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        palette,
                        Icons.vibration,
                        'Haptic Feedback',
                        null,
                        _haptics,
                        (v) => setState(() => _haptics = v),
                      ),
                      Divider(color: palette.divider, height: 1),
                      _buildSwitchTile(
                        palette,
                        Icons.notifications,
                        'Game Notifications',
                        null,
                        _notifications,
                        (v) => setState(() => _notifications = v),
                      ),
                      Divider(color: palette.divider, height: 1),
                      _buildSwitchTile(
                        palette,
                        Icons.face,
                        'Show Player Avatars',
                        null,
                        _showAvatars,
                        (v) => setState(() => _showAvatars = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                const _SectionHeader('APPEARANCE'),
                Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                  ),
                  padding: const EdgeInsets.all(AppDimens.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Theme',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimens.paddingM),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: AppThemeMode.values.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppDimens.paddingM),
                          itemBuilder: (context, index) {
                            final mode = AppThemeMode.values[index];
                            final isSelected = themeState.mode == mode;
                            final themePalette = AppColors.getPalette(mode);

                            return GestureDetector(
                              onTap: () => context.read<ThemeBloc>().add(
                                ThemeChanged(mode),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: themePalette.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? palette.primary
                                            : themePalette.divider,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: palette.primary
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: themePalette.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mode.name.toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? palette.primary
                                          : palette.textTertiary,
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                const _SectionHeader('GENERAL'),
                Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                  ),
                  child: Column(
                    children: [
                      _buildNavTile(
                        palette,
                        Icons.language,
                        'Language',
                        'English',
                      ),
                      Divider(color: palette.divider, height: 1),
                      _buildGraphicsTile(palette),
                      Divider(color: palette.divider, height: 1),
                      _buildNavTile(
                        palette,
                        Icons.book_outlined,
                        'Game Rules',
                        null,
                        onTap: () => Navigator.pushNamed(context, '/rules'),
                      ),
                      Divider(color: palette.divider, height: 1),
                      _buildNavTile(
                        palette,
                        Icons.help,
                        'Help & Support',
                        null,
                      ),
                      if (AppConfig.instance.isDevelopment ||
                          FirebaseAuth.instance.currentUser?.uid ==
                              AppConfig.instance.masterAdminId) ...[
                        Divider(color: palette.divider, height: 1),
                        _buildNavTile(
                          palette,
                          Icons.admin_panel_settings,
                          'Admin Dashboard',
                          null,
                          onTap: () => Navigator.pushNamed(context, '/admin'),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.paddingXL),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: palette.divider),
                      foregroundColor: palette.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusM),
                      ),
                    ),
                    onPressed: () {
                      context.read<AuthBloc>().add(SignOutRequested());
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/splash', (route) => false);
                    },
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Sign Out'),
                  ),
                ),

                const SizedBox(height: AppDimens.paddingL),
                Center(
                  child: Text(
                    'VERSION 2.4.1 (BUILD 890)',
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.paddingXL),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile(
    AppColorPalette palette,
    IconData icon,
    String title,
    String? subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: palette.textSecondary, size: 18),
          ),
          const SizedBox(width: AppDimens.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: palette.textPrimary, fontSize: 16),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(color: palette.textTertiary, fontSize: 12),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.primary,
            activeTrackColor: palette.primaryDim,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    AppColorPalette palette,
    IconData icon,
    String title,
    String? trailingText, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.paddingM,
          vertical: 16,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: palette.textSecondary, size: 18),
            ),
            const SizedBox(width: AppDimens.paddingM),
            Text(
              title,
              style: TextStyle(color: palette.textPrimary, fontSize: 16),
            ),
            const Spacer(),
            if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(color: palette.textSecondary, fontSize: 14),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: palette.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphicsTile(AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hd, color: palette.textSecondary, size: 18),
          ),
          const SizedBox(width: AppDimens.paddingM),
          Text(
            'Graphics',
            style: TextStyle(color: palette.textPrimary, fontSize: 16),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.divider),
            ),
            child: Row(
              children: [
                _buildGraphicsOption(palette, 'Low', false),
                _buildGraphicsOption(palette, 'High', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphicsOption(
    AppColorPalette palette,
    String label,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected ? palette.surfaceLight : Colors.transparent,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? palette.textPrimary : palette.textTertiary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          final palette = AppColors.getPalette(state.mode);
          return Text(
            title,
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }
}
