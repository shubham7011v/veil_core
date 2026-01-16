import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/theme/bloc/theme_event.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/dimens.dart';
import '../../../auth/auth.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/services/audio/audio_service_interface.dart';
import '../../../../core/constants/sound_assets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import '../widgets/settings_about_section.dart';
import '../widgets/settings_components.dart';
import '../widgets/settings_audio_section.dart';
import '../widgets/settings_gameplay_section.dart';
import '../widgets/settings_appearance_section.dart';
import '../widgets/settings_account_section.dart';
import '../widgets/settings_performance_section.dart';
import '../widgets/settings_legal_section.dart';
import '../widgets/settings_support_section.dart';

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
      AppLogger.error('Failed to get package info', exception: e);
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
                SettingsSectionHeader(title: 'AUDIO', palette: palette),
                SettingsAudioSection(
                  palette: palette,
                  masterVolume: _masterVolume,
                  voiceVolume: _voiceVolume,
                  musicVolume: _musicVolume,
                  sfxVolume: _sfxVolume,
                  musicEnabled: _music,
                  sfxEnabled: _sfx,
                  sfxVariant: _sfxVariant,
                  onMasterChanged: (v) => setState(() {
                    _masterVolume = v;
                    _updateSetting('pref_master_volume', v);
                    _playVolumePreview();
                  }),
                  onVoiceChanged: (v) => setState(() {
                    _voiceVolume = v;
                    _updateSetting('pref_voice_volume', v);
                    _playVolumePreview();
                  }),
                  onMusicChanged: (v) => setState(() {
                    _musicVolume = v;
                    _updateSetting('pref_music_volume', v);
                    _playVolumePreview();
                  }),
                  onSfxChanged: (v) => setState(() {
                    _sfxVolume = v;
                    _updateSetting('pref_sfx_volume', v);
                    _playVolumePreview();
                  }),
                  onMusicToggle: (v) => setState(() {
                    _music = v;
                    _updateSetting('pref_music', v);
                  }),
                  onSfxToggle: (v) => setState(() {
                    _sfx = v;
                    _updateSetting('pref_sfx', v);
                  }),
                  onVariantChanged: (index) => setState(() {
                    _sfxVariant = index;
                    _updateSetting('pref_sfx_variant', index);
                  }),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsSectionHeader(title: 'GAMEPLAY', palette: palette),
                SettingsGameplaySection(
                  palette: palette,
                  shuffleAnimation: _shuffleAnimation,
                  haptics: _haptics,
                  confirmBluff: _confirmBluff,
                  autoSort: _autoSort,
                  notifications: _notifications,
                  showAvatars: _showAvatars,
                  onShuffleAnimationChanged: (v) => setState(() {
                    _shuffleAnimation = v;
                    _updateSetting('pref_shuffle_animation', v);
                  }),
                  onHapticsChanged: (v) => setState(() {
                    _haptics = v;
                    _updateSetting('pref_haptics', v);
                  }),
                  onConfirmBluffChanged: (v) => setState(() {
                    _confirmBluff = v;
                    _updateSetting('pref_confirm_bluff', v);
                  }),
                  onAutoSortChanged: (v) => setState(() {
                    _autoSort = v;
                    _updateSetting('pref_auto_sort', v);
                  }),
                  onNotificationsChanged: (v) => setState(() {
                    _notifications = v;
                    _updateSetting('pref_notifications', v);
                  }),
                  onShowAvatarsChanged: (v) => setState(() {
                    _showAvatars = v;
                    _updateSetting('pref_show_avatars', v);
                  }),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsSectionHeader(title: 'APPEARANCE', palette: palette),
                SettingsAppearanceSection(
                  palette: palette,
                  themeState: themeState,
                  onThemeChanged: (mode) =>
                      context.read<ThemeBloc>().add(ThemeChanged(mode)),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsSectionHeader(
                  title: 'ACCOUNT & SECURITY',
                  palette: palette,
                ),
                SettingsAccountSection(
                  palette: palette,
                  onSignOut: _showSignOutConfirm,
                  onDeleteAccount: _showDeleteAccountConfirm,
                ),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsSectionHeader(title: 'PERFORMANCE', palette: palette),
                SettingsPerformanceSection(
                  palette: palette,
                  graphicsQuality: _graphics,
                  dataSaver: _dataSaver,
                  onGraphicsChanged: (v) => setState(() {
                    if (v != null) {
                      _graphics = v;
                      _updateSetting('pref_graphics', v);
                    }
                  }),
                  onDataSaverChanged: (v) => setState(() {
                    _dataSaver = v;
                    _updateSetting('pref_data_saver', v);
                  }),
                ),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsSectionHeader(
                  title: 'PRIVACY & LEGAL',
                  palette: palette,
                ),
                SettingsLegalSection(palette: palette, onLaunchURL: _launchURL),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsSectionHeader(
                  title: 'HELP & SUPPORT',
                  palette: palette,
                ),
                SettingsSupportSection(
                  palette: palette,
                  onLaunchURL: _launchURL,
                ),

                const SizedBox(height: AppDimens.paddingXL),
                SettingsAboutSection(
                  palette: palette,
                  version: _version,
                  buildNumber: _buildNumber,
                  onOpenAdmin: () => Navigator.pushNamed(context, '/admin'),
                  onOpenSoundTest: () =>
                      Navigator.pushNamed(context, '/sound_test'),
                ),

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

  // --- HELPERS ---

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
