import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import 'settings_components.dart';

class SettingsAudioSection extends StatelessWidget {
  final AppColorPalette palette;
  final double masterVolume;
  final double voiceVolume;
  final double musicVolume;
  final double sfxVolume;
  final bool musicEnabled;
  final bool sfxEnabled;
  final int sfxVariant;
  final ValueChanged<double> onMasterChanged;
  final ValueChanged<double> onVoiceChanged;
  final ValueChanged<double> onMusicChanged;
  final ValueChanged<double> onSfxChanged;
  final ValueChanged<bool> onMusicToggle;
  final ValueChanged<bool> onSfxToggle;
  final ValueChanged<int> onVariantChanged;

  const SettingsAudioSection({
    super.key,
    required this.palette,
    required this.masterVolume,
    required this.voiceVolume,
    required this.musicVolume,
    required this.sfxVolume,
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.sfxVariant,
    required this.onMasterChanged,
    required this.onVoiceChanged,
    required this.onMusicChanged,
    required this.onSfxChanged,
    required this.onMusicToggle,
    required this.onSfxToggle,
    required this.onVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      palette: palette,
      children: [
        SettingsVolumeSlider(
          label: 'Master Volume',
          value: masterVolume,
          onChanged: onMasterChanged,
          palette: palette,
        ),
        SettingsVolumeSlider(
          label: 'Voice Volume',
          value: voiceVolume,
          onChanged: onVoiceChanged,
          palette: palette,
        ),
        SettingsVolumeSlider(
          label: 'Music Volume',
          value: musicVolume,
          onChanged: onMusicChanged,
          palette: palette,
        ),
        SettingsVolumeSlider(
          label: 'SFX Volume',
          value: sfxVolume,
          onChanged: onSfxChanged,
          palette: palette,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.music_note_rounded,
          title: 'Music',
          subtitle: 'Background ambient music',
          value: musicEnabled,
          palette: palette,
          onChanged: onMusicToggle,
        ),
        SettingsDivider(palette: palette),
        SettingsSwitchTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Sound Effects',
          subtitle: 'Card & chip interactions',
          value: sfxEnabled,
          palette: palette,
          onChanged: onSfxToggle,
        ),
        SettingsDivider(palette: palette),
        _buildVariantSelector(),
      ],
    );
  }

  Widget _buildVariantSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SFX Style',
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
              final isSelected = variant == sfxVariant;
              return GestureDetector(
                onTap: () => onVariantChanged(variant),
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
}
