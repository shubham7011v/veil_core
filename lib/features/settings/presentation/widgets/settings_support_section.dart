import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/config/app_config.dart';
import 'settings_components.dart';

class SettingsSupportSection extends StatelessWidget {
  final AppColorPalette palette;
  final Function(String) onLaunchURL;

  const SettingsSupportSection({
    super.key,
    required this.palette,
    required this.onLaunchURL,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      palette: palette,
      children: [
        SettingsActionTile(
          icon: Icons.help_outline_rounded,
          title: 'Game Rules',
          palette: palette,
          onTap: () => onLaunchURL(AppConfig.instance.gameRulesUrl),
        ),
        SettingsDivider(palette: palette),
        SettingsActionTile(
          icon: Icons.bug_report_rounded,
          title: 'Report a Bug',
          palette: palette,
          onTap: () => onLaunchURL(
            'mailto:${AppConfig.instance.supportEmail}?subject=Bug%20Report',
          ),
        ),
        SettingsDivider(palette: palette),
        SettingsActionTile(
          icon: Icons.contact_support_rounded,
          title: 'Contact Support',
          palette: palette,
          onTap: () => onLaunchURL('mailto:${AppConfig.instance.supportEmail}'),
        ),
      ],
    );
  }
}
