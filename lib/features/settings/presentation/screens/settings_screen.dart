import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/theme/bloc/theme_event.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/dimens.dart';
import '../../../auth/auth.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/audio/audio_service_interface.dart';
import '../../../../core/constants/sound_assets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import '../../../../core/config/feature_flags.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Audio
  double _masterVolume = 75;
  double _voiceVolume = 85;
  double _musicVolume = 35;
  double _sfxVolume = 70;
  bool _music = true;
  bool _sfx = true;
  int _sfxVariant = 1;

  // Gameplay
  bool _shuffleAnimation = true;
  bool _haptics = true;
  bool _notifications = true;
  bool _showAvatars = true;
  bool _confirmBluff = true;
  bool _autoSort = true;

  // Performance
  String _graphics = 'Medium';
  bool _dataSaver = false;

  // Version Info
  String _version = '2.4.1'; // Fallback
  String _buildNumber = '890'; // Fallback

  Timer? _volumePreviewTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version.isNotEmpty ? info.version : '2.4.1';
          _buildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : '890';
        });
      }
    } catch (e) {
      debugPrint('Failed to get package info: $e');
    }
  }

  Future<void> _loadSettings() async {
    final storage = sl.storageService;
    setState(() {
      _masterVolume = storage.getInt('pref_master_volume')?.toDouble() ?? 75.0;
      _voiceVolume = storage.getInt('pref_voice_volume')?.toDouble() ?? 85.0;
      _musicVolume = storage.getInt('pref_music_volume')?.toDouble() ?? 35.0;
      _sfxVolume = storage.getInt('pref_sfx_volume')?.toDouble() ?? 70.0;
      _music = storage.getBool('pref_music') ?? true;
      _sfx = storage.getBool('pref_sfx') ?? true;
      _shuffleAnimation = storage.getBool('pref_shuffle_animation') ?? true;
      _haptics = storage.getBool('pref_haptics') ?? true;
      _notifications = storage.getBool('pref_notifications') ?? true;
      _showAvatars = storage.getBool('pref_show_avatars') ?? true;
      _confirmBluff = storage.getBool('pref_confirm_bluff') ?? true;
      _autoSort = storage.getBool('pref_auto_sort') ?? true;
      _graphics = storage.getString('pref_graphics') ?? 'Medium';
      _dataSaver = storage.getBool('pref_data_saver') ?? false;
      _sfxVariant = storage.getInt('pref_sfx_variant') ?? 1;
    });

    // Apply initial settings to Audio Engine
    _applyAudioSettings();
  }

  void _applyAudioSettings() {
    sl.audioService.updateVolumes(
      AudioSettings(
        masterVolume: _masterVolume / 100,
        musicVolume: _musicVolume / 100,
        sfxVolume: _sfxVolume / 100,
        voiceVolume: _voiceVolume / 100,
        isMusicEnabled: _music,
        isSfxEnabled: _sfx,
        isVoiceEnabled: true,
        isHapticEnabled: _haptics,
        sfxVariantIndex: _sfxVariant,
      ),
    );
  }

  void _updateSetting(String key, dynamic value) {
    final storage = sl.storageService;
    if (value is bool) storage.setBool(key, value);
    if (value is String) storage.setString(key, value);
    if (value is int) storage.setInt(key, value);
    if (value is double) storage.setInt(key, value.toInt());

    // Update Audio Engine real-time
    _applyAudioSettings();
  }

  void _playVolumePreview() {
    // Debounce to avoid spamming sounds while sliding
    _volumePreviewTimer?.cancel();
    _volumePreviewTimer = Timer(const Duration(milliseconds: 150), () {
      sl.audioService.playSfx(SoundAssets.buttonTap);
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: _buildAppBar(palette),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingM,
              ),
              children: [
                const SizedBox(height: AppDimens.paddingM),
                _buildSectionHeader('AUDIO', palette),
                _buildAudioSection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildSectionHeader('GAMEPLAY', palette),
                _buildGameplaySection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildSectionHeader('APPEARANCE', palette),
                _buildAppearanceSection(themeState, palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildSectionHeader('ACCOUNT & SECURITY', palette),
                _buildAccountSection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildSectionHeader('PERFORMANCE', palette),
                _buildPerformanceSection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildSectionHeader('PRIVACY & LEGAL', palette),
                _buildLegalSection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildSectionHeader('HELP & SUPPORT', palette),
                _buildSupportSection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildAboutSection(palette),

                const SizedBox(height: AppDimens.paddingXL),
                _buildServerInfo(palette),

                const SizedBox(height: AppDimens.paddingXL),
                const SizedBox(height: AppDimens.paddingXL),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorPalette palette) {
    return AppBar(
      title: const Text(
        'SETTINGS',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: palette.textSecondary,
          size: 20,
        ),
        onPressed: () =>
            widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: palette.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard({
    required List<Widget> children,
    required AppColorPalette palette,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        border: Border.all(color: palette.divider.withValues(alpha: 0.1)),
      ),
      child: Column(children: children),
    );
  }

  // --- AUDIO SECTION ---
  Widget _buildAudioSection(AppColorPalette palette) {
    return _buildCard(
      palette: palette,
      children: [
        _buildVolumeSlider('Master Volume', _masterVolume, (v) {
          setState(() {
            _masterVolume = v;
            _updateSetting('pref_master_volume', v);
            _playVolumePreview();
          });
        }, palette),
        _buildVolumeSlider('Voice Volume', _voiceVolume, (v) {
          setState(() {
            _voiceVolume = v;
            _updateSetting('pref_voice_volume', v);
            _playVolumePreview();
          });
        }, palette),
        _buildVolumeSlider('Music Volume', _musicVolume, (v) {
          setState(() {
            _musicVolume = v;
            _updateSetting('pref_music_volume', v);
            _playVolumePreview();
          });
        }, palette),
        _buildVolumeSlider('SFX Volume', _sfxVolume, (v) {
          setState(() {
            _sfxVolume = v;
            _updateSetting('pref_sfx_volume', v);
            _playVolumePreview();
          });
        }, palette),
        // TODO: Consider adding more granular audio controls, such as individual SFX variant selection
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.music_note_rounded,
          title: 'Music',
          subtitle: 'Background ambient music',
          value: _music,
          palette: palette,
          onChanged: (v) => setState(() {
            _music = v;
            _updateSetting('pref_music', v);
          }),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Sound Effects',
          subtitle: 'Card & chip interactions',
          value: _sfx,
          palette: palette,
          onChanged: (v) => setState(() {
            _sfx = v;
            _updateSetting('pref_sfx', v);
          }),
        ),
        _buildDivider(palette),
        _buildVariantSelector(
          'SFX Style',
          _sfxVariant,
          (index) => setState(() {
            _sfxVariant = index;
            _updateSetting('pref_sfx_variant', index);
          }),
          palette,
        ),
      ],
    );
  }

  Widget _buildVariantSelector(
    String label,
    int currentValue,
    ValueChanged<int> onChanged,
    AppColorPalette palette,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final variant = index + 1;
              final isSelected = variant == currentValue;
              return GestureDetector(
                onTap: () => onChanged(variant),
                child: Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primary : palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.divider,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'V$variant',
                    style: TextStyle(
                      color: isSelected ? Colors.white : palette.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
    AppColorPalette palette,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                label.contains('Voice')
                    ? Icons.mic_rounded
                    : label.contains('Music')
                    ? Icons.music_note_rounded
                    : label.contains('SFX')
                    ? Icons.graphic_eq_rounded
                    : Icons.volume_up_rounded,
                color: palette.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${value.toInt()}%',
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.primary,
              inactiveTrackColor: palette.surface,
              thumbColor: palette.primary,
              overlayColor: palette.primary.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(value: value, min: 0, max: 100, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  // --- GAMEPLAY SECTION ---
  Widget _buildGameplaySection(AppColorPalette palette) {
    return _buildCard(
      palette: palette,
      children: [
        _buildSwitchTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Shuffle Animation',
          value: _shuffleAnimation,
          palette: palette,
          onChanged: (v) => setState(() {
            _shuffleAnimation = v;
            _updateSetting('pref_shuffle_animation', v);
          }),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback',
          value: _haptics,
          palette: palette,
          onChanged: (v) => setState(() {
            _haptics = v;
            _updateSetting('pref_haptics', v);
          }),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.warning_amber_rounded,
          title: 'Confirm Before Bluff',
          subtitle: 'Prevents accidental taps',
          value: _confirmBluff,
          palette: palette,
          onChanged: (v) => setState(() {
            _confirmBluff = v;
            _updateSetting('pref_confirm_bluff', v);
          }),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.sort_rounded,
          title: 'Card Auto-Sort',
          value: _autoSort,
          palette: palette,
          onChanged: (v) => setState(() {
            _autoSort = v;
            _updateSetting('pref_auto_sort', v);
          }),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.notifications_rounded,
          title: 'Game Notifications',
          value: _notifications,
          palette: palette,
          onChanged: (v) => setState(() {
            _notifications = v;
            _updateSetting('pref_notifications', v);
          }),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.face_rounded,
          title: 'Show Player Avatars',
          value: _showAvatars,
          palette: palette,
          onChanged: (v) => setState(() {
            _showAvatars = v;
            _updateSetting('pref_show_avatars', v);
          }),
        ),
      ],
    );
  }

  // --- APPEARANCE SECTION ---
  Widget _buildAppearanceSection(
    ThemeState themeState,
    AppColorPalette palette,
  ) {
    return _buildCard(
      palette: palette,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Theme',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: AppThemeMode.values.map((mode) {
                    final isSelected = themeState.mode == mode;
                    final modePalette = AppColors.getPalette(mode);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () =>
                            context.read<ThemeBloc>().add(ThemeChanged(mode)),
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? palette.primary
                                  : palette.divider,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: modePalette.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: modePalette.divider,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: modePalette.primary,
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
                                      : palette.textSecondary,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- ACCOUNT SECTION ---
  Widget _buildAccountSection(AppColorPalette palette) {
    final user = FirebaseAuth.instance.currentUser;
    return _buildCard(
      palette: palette,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null ? const Icon(Icons.person) : null,
          ),
          title: Text(
            user?.displayName ?? 'Guest',
            style: TextStyle(color: palette.textPrimary),
          ),
          subtitle: Text(
            user?.email ?? user?.uid ?? 'Not logged in',
            style: TextStyle(color: palette.textTertiary, fontSize: 12),
          ),
        ),
        _buildDivider(palette),
        _buildActionTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          color: palette.textSecondary,
          palette: palette,
          onTap: _showSignOutConfirm,
        ),
        _buildDivider(palette),
        _buildActionTile(
          icon: Icons.delete_forever_rounded,
          title: 'Delete Account',
          color: Colors.redAccent,
          palette: palette,
          onTap: _showDeleteAccountConfirm,
        ),
      ],
    );
  }

  // --- PERFORMANCE SECTION ---
  Widget _buildPerformanceSection(AppColorPalette palette) {
    return _buildCard(
      palette: palette,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingM,
            vertical: 8,
          ),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded, size: 20),
              const SizedBox(width: 12),
              Text('Graphics', style: TextStyle(color: palette.textPrimary)),
              const Spacer(),
              DropdownButton<String>(
                value: _graphics,
                dropdownColor: palette.surfaceLight,
                underline: const SizedBox(),
                items: ['Low', 'Medium', 'High']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  if (v != null) {
                    _graphics = v;
                    _updateSetting('pref_graphics', v);
                  }
                }),
              ),
            ],
          ),
        ),
        _buildDivider(palette),
        _buildSwitchTile(
          icon: Icons.data_usage_rounded,
          title: 'Data Saver Mode',
          subtitle: 'Lower bandwidth usage',
          value: _dataSaver,
          palette: palette,
          onChanged: (v) => setState(() {
            _dataSaver = v;
            _updateSetting('pref_data_saver', v);
          }),
        ),
      ],
    );
  }

  // --- PRIVACY & LEGAL SECTION ---
  Widget _buildLegalSection(AppColorPalette palette) {
    return _buildCard(
      palette: palette,
      children: [
        _buildActionTile(
          icon: Icons.description_rounded,
          title: 'Terms of Service',
          palette: palette,
          onTap: () => _launchURL(AppConfig.instance.termsUrl),
        ),
        _buildDivider(palette),
        _buildActionTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          palette: palette,
          onTap: () => _launchURL(AppConfig.instance.privacyPolicyUrl),
        ),
        _buildDivider(palette),
        _buildActionTile(
          icon: Icons.info_outline_rounded,
          title: 'Data Usage Info',
          palette: palette,
          onTap: () => _launchURL(AppConfig.instance.dataUsageUrl),
        ),
      ],
    );
  }

  // --- SUPPORT SECTION ---
  Widget _buildSupportSection(AppColorPalette palette) {
    return _buildCard(
      palette: palette,
      children: [
        _buildActionTile(
          icon: Icons.help_outline_rounded,
          title: 'Game Rules',
          palette: palette,
          onTap: () => _launchURL(AppConfig.instance.gameRulesUrl),
        ),
        _buildDivider(palette),
        _buildActionTile(
          icon: Icons.bug_report_rounded,
          title: 'Report a Bug',
          palette: palette,
          onTap: () => _launchURL(
            'mailto:${AppConfig.instance.supportEmail}?subject=Bug%20Report',
          ),
        ),
        _buildDivider(palette),
        _buildActionTile(
          icon: Icons.contact_support_rounded,
          title: 'Contact Support',
          palette: palette,
          onTap: () => _launchURL('mailto:${AppConfig.instance.supportEmail}'),
        ),
      ],
    );
  }

  // --- ABOUT SECTION ---
  Widget _buildAboutSection(AppColorPalette palette) {
    return Column(
      children: [
        Text(
          'BLUFF MULTIPLAYER',
          style: TextStyle(
            color: palette.textPrimary.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version $_version • Build $_buildNumber',
          style: TextStyle(color: palette.textTertiary, fontSize: 10),
        ),
        if (FeatureFlags.enableAdminDashboard &&
            (AppConfig.instance.isAdmin ||
                AppConfig.instance.adminUids.contains(
                  FirebaseAuth.instance.currentUser?.uid,
                ))) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            icon: Icon(Icons.security, size: 14, color: palette.textTertiary),
            label: Text(
              'ADMIN PANEL',
              style: TextStyle(
                color: palette.textTertiary,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/sound_test'),
          icon: Icon(Icons.music_note, size: 14, color: palette.textTertiary),
          label: Text(
            'SOUND TEST',
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required AppColorPalette palette,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: palette.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(color: palette.textPrimary, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: palette.textTertiary, fontSize: 12),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: palette.primary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Color? color,
    required AppColorPalette palette,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? palette.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(color: color ?? palette.textPrimary, fontSize: 15),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: palette.textTertiary,
        size: 18,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
      ),
    );
  }

  Widget _buildServerInfo(AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SERVER CONNECTION',
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.divider.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.dns_rounded, size: 16, color: palette.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppConfig.instance.serverUrl,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppColorPalette palette) {
    return Divider(
      height: 1,
      indent: 50,
      color: palette.divider.withValues(alpha: 0.05),
    );
  }

  void _showSignOutConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(SignOutRequested());
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/splash',
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your progress, coins, and stats will be lost forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep My Account'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _showDeleteAccountFinalConfirmation();
            },
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountFinalConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Warning'),
        content: const Text('Are you REALLY sure? There is no going back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Changed My Mind'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(DeleteAccountRequested());
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/splash',
                (route) => false,
              );
            },
            child: const Text('DELETE FOREVER'),
          ),
        ],
      ),
    );
  }
}
