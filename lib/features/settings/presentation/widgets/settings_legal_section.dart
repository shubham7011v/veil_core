import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/config/app_config.dart';
import 'settings_components.dart';

class SettingsLegalSection extends StatelessWidget {
  final AppColorPalette palette;
  final Function(String) onLaunchURL;

  const SettingsLegalSection({
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
          icon: Icons.description_rounded,
          title: 'Terms of Service',
          palette: palette,
          onTap: () => onLaunchURL(AppConfig.instance.termsUrl),
        ),
        SettingsDivider(palette: palette),
        SettingsActionTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          palette: palette,
          onTap: () => onLaunchURL(AppConfig.instance.privacyPolicyUrl),
        ),
        SettingsDivider(palette: palette),
        SettingsActionTile(
          icon: Icons.info_outline_rounded,
          title: 'Data Usage Info',
          palette: palette,
          onTap: () => onLaunchURL(AppConfig.instance.dataUsageUrl),
        ),
      ],
    );
  }
}
