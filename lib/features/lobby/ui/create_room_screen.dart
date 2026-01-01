import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/components/primary_button.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  double _bootAmount = 5000;
  int _selectedPlayerCount = 5;
  bool _voiceChat = true;
  bool _spectatorMode = false;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'CREATE ROOM',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: Responsive.sp(18),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Image Placeholder
                    Container(
                      height: Responsive.h(180),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppDimens.radiusL),
                        image: const DecorationImage(
                          image: AssetImage(
                            'assets/images/room_header_placeholder.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: EdgeInsets.all(
                          Responsive.w(AppDimens.paddingM),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CLASSIC MODE',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: Responsive.sp(10),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingL)),

                    // Room Type
                    Row(
                      children: [
                        Expanded(
                          child: _buildRoomTypeOption('Public Match', false),
                        ),
                        SizedBox(width: Responsive.w(AppDimens.paddingM)),
                        Expanded(
                          child: _buildRoomTypeOption('Private Room', true),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingL)),

                    // Room Name Input
                    Text(
                      'ROOM NAME',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.sp(12),
                      ),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    _buildTextField(Icons.meeting_room, 'Royal Lounge #88'),

                    SizedBox(height: Responsive.h(AppDimens.paddingL)),

                    // Password
                    Text(
                      'PASSWORD (OPTIONAL)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.sp(12),
                      ),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    _buildTextField(
                      Icons.lock,
                      'Set a secure password',
                      isPassword: true,
                    ),

                    SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                    // Boot Amount Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BOOT AMOUNT',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryDim),
                          ),
                          child: Text(
                            '\$ ${_bootAmount.toInt()}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.surfaceLight,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.activeGlow,
                      ),
                      child: Slider(
                        value: _bootAmount,
                        min: 500,
                        max: 50000,
                        divisions: 99,
                        onChanged: (val) => setState(() => _bootAmount = val),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '500',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: Responsive.sp(10),
                          ),
                        ),
                        Text(
                          '50k',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: Responsive.sp(10),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                    // Player Count
                    const Text(
                      'NUMBER OF PLAYERS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        2,
                        3,
                        4,
                        5,
                      ].map((count) => _buildPlayerCountOption(count)).toList(),
                    ),

                    SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                    // Toggles
                    _buildToggle(
                      'Voice Chat',
                      'Allow participants to talk',
                      _voiceChat,
                      (v) => setState(() => _voiceChat = v),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    _buildToggle(
                      'Spectator Mode',
                      'Allow friends to watch',
                      _spectatorMode,
                      (v) => setState(() => _spectatorMode = v),
                    ),

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Entry Fee',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${_bootAmount.toInt()}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: Responsive.sp(18),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(AppDimens.paddingM)),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Create Room',
                      icon: Icons.arrow_forward,
                      onPressed: () {
                        // Navigate to Lobby
                        Navigator.pushReplacementNamed(context, '/lobby');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTypeOption(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        border: isSelected ? null : Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : AppColors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String hint, {
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusS),
      ),
      child: TextField(
        obscureText: isPassword,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textTertiary),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: isPassword
              ? const Icon(Icons.visibility_off, color: AppColors.textTertiary)
              : null,
        ),
      ),
    );
  }

  Widget _buildPlayerCountOption(int count) {
    final isSelected = _selectedPlayerCount == count;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlayerCount = count),
      child: Container(
        width: Responsive.w(70),
        height: Responsive.w(70), // Keep square
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceLight
              : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              value ? Icons.mic : Icons.visibility,
              color: AppColors.primaryDim,
              size: 20,
            ),
          ),
          SizedBox(width: Responsive.w(AppDimens.paddingM)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
}
