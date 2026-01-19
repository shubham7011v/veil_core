import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import 'settings_components.dart';

class SettingsPerformanceSection extends StatelessWidget {
  final AppColorPalette palette;
  final String graphicsQuality;
  final bool dataSaver;
  final ValueChanged<String?> onGraphicsChanged;
  final ValueChanged<bool> onDataSaverChanged;

  const SettingsPerformanceSection({
    super.key,
    required this.palette,
    required this.graphicsQuality,
    required this.dataSaver,
    required this.onGraphicsChanged,
    required this.onDataSaverChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
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
                value: graphicsQuality,
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
                onChanged: onGraphicsChanged,
              ),
            ],
          ),
        ),
        if (false) ...[
          SettingsDivider(palette: palette),
          SettingsSwitchTile(
            icon: Icons.data_usage_rounded,
            title: 'Data Saver Mode',
            subtitle: 'Lower bandwidth usage',
            value: dataSaver,
            palette: palette,
            onChanged: onDataSaverChanged,
          ),
        ],
      ],
    );
  }
}
