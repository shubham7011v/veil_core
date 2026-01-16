import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';

/// Reusable settings card container with rounded corners and border.
class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final AppColorPalette palette;

  const SettingsCard({
    super.key,
    required this.children,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        border: Border.all(color: palette.divider.withValues(alpha: 0.1)),
      ),
      child: Column(children: children),
    );
  }
}

/// Settings section header text.
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final AppColorPalette palette;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Switch tile for boolean settings.
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final AppColorPalette palette;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
      ),
      leading: Icon(icon, color: palette.primary, size: 22),
      title: Text(title, style: TextStyle(color: palette.textPrimary)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: palette.textTertiary, fontSize: 12),
            )
          : null,
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }
}

/// Action tile for tappable settings.
class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final AppColorPalette palette;
  final VoidCallback onTap;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
      ),
      leading: Icon(icon, color: color ?? palette.primary, size: 22),
      title: Text(title, style: TextStyle(color: color ?? palette.textPrimary)),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
      onTap: onTap,
    );
  }
}

/// Thin divider for settings sections.
class SettingsDivider extends StatelessWidget {
  final AppColorPalette palette;

  const SettingsDivider({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: palette.divider.withValues(alpha: 0.1),
      height: 1,
      indent: AppDimens.paddingM,
      endIndent: AppDimens.paddingM,
    );
  }
}

/// Volume slider for audio settings.
class SettingsVolumeSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final AppColorPalette palette;

  const SettingsVolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.palette,
  });

  IconData get _icon {
    if (label.contains('Voice')) return Icons.mic_rounded;
    if (label.contains('Music')) return Icons.music_note_rounded;
    if (label.contains('SFX')) return Icons.graphic_eq_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_icon, color: palette.primary, size: 20),
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
}
