import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.background,
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.primary,
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
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusM),
              ),
              padding: const EdgeInsets.all(AppDimens.paddingM),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_up, color: AppColors.primary),
                      const SizedBox(width: AppDimens.paddingM),
                      const Text(
                        'Master Volume',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_masterVolume.toInt()}%',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.surface,
                      thumbColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: _masterVolume,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setState(() => _masterVolume = v),
                    ),
                  ),
                  const Divider(color: AppColors.divider),
                  _buildSwitchTile(
                    Icons.music_note,
                    'Music',
                    'Background score',
                    _music,
                    (v) => setState(() => _music = v),
                  ),
                  const Divider(color: AppColors.divider),
                  _buildSwitchTile(
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
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusM),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    Icons.vibration,
                    'Haptic Feedback',
                    null,
                    _haptics,
                    (v) => setState(() => _haptics = v),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildSwitchTile(
                    Icons.notifications,
                    'Game Notifications',
                    null,
                    _notifications,
                    (v) => setState(() => _notifications = v),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildSwitchTile(
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
            const _SectionHeader('GENERAL'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusM),
              ),
              child: Column(
                children: [
                  _buildNavTile(Icons.language, 'Language', 'English'),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildGraphicsTile(),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildNavTile(Icons.help, 'Help & Support', null),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.paddingXL),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.divider),
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Sign Out'),
              ),
            ),

            const SizedBox(height: AppDimens.paddingL),
            const Center(
              child: Text(
                'VERSION 2.4.1 (BUILD 890)',
                style: TextStyle(
                  color: AppColors.textTertiary,
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
  }

  Widget _buildSwitchTile(
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
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: AppDimens.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryDim,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(IconData icon, String title, String? trailingText) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingM,
        vertical: 16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: AppDimens.paddingM),
          Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          const Spacer(),
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildGraphicsTile() {
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
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hd,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppDimens.paddingM),
          const Text(
            'Graphics',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                _buildGraphicsOption('Low', false),
                _buildGraphicsOption('High', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphicsOption(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected ? AppColors.surfaceLight : Colors.transparent,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
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
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
