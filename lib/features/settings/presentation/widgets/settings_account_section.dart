import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/colors.dart';
import 'settings_components.dart';

class SettingsAccountSection extends StatelessWidget {
  final AppColorPalette palette;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const SettingsAccountSection({
    super.key,
    required this.palette,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return SettingsCard(
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
        SettingsDivider(palette: palette),
        SettingsActionTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          color: palette.textSecondary,
          palette: palette,
          onTap: onSignOut,
        ),
        SettingsDivider(palette: palette),
        SettingsActionTile(
          icon: Icons.delete_forever_rounded,
          title: 'Delete Account',
          color: Colors.redAccent,
          palette: palette,
          onTap: onDeleteAccount,
        ),
      ],
    );
  }
}
