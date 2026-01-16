import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import 'settings_components.dart';

class SettingsGameplaySection extends StatelessWidget {
  final AppColorPalette palette;
  final bool shuffleAnimation;
  final bool haptics;
  final bool confirmBluff;
  final bool autoSort;
  final bool notifications;
  final bool showAvatars;
  final ValueChanged<bool> onShuffleAnimationChanged;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onConfirmBluffChanged;
  final ValueChanged<bool> onAutoSortChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onShowAvatarsChanged;

  const SettingsGameplaySection({
    super.key,
    required this.palette,
    required this.shuffleAnimation,
    required this.haptics,
    required this.confirmBluff,
    required this.autoSort,
    required this.notifications,
    required this.showAvatars,
    required this.onShuffleAnimationChanged,
    required this.onHapticsChanged,
    required this.onConfirmBluffChanged,
    required this.onAutoSortChanged,
    required this.onNotificationsChanged,
    required this.onShowAvatarsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      palette: palette,
      children: [
        SettingsSwitchTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Shuffle Animation',
          value: shuffleAnimation,
          palette: palette,
          onChanged: onShuffleAnimationChanged,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback',
          value: haptics,
          palette: palette,
          onChanged: onHapticsChanged,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.warning_amber_rounded,
          title: 'Confirm Before Bluff',
          subtitle: 'Prevents accidental taps',
          value: confirmBluff,
          palette: palette,
          onChanged: onConfirmBluffChanged,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.sort_rounded,
          title: 'Card Auto-Sort',
          value: autoSort,
          palette: palette,
          onChanged: onAutoSortChanged,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.notifications_rounded,
          title: 'Game Notifications',
          value: notifications,
          palette: palette,
          onChanged: onNotificationsChanged,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.face_rounded,
          title: 'Show Player Avatars',
          value: showAvatars,
          palette: palette,
          onChanged: onShowAvatarsChanged,
        ),
      ],
    );
  }
}
