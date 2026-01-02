import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants/dimens.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/components/primary_button.dart';
import '../../../shared/components/glass_container.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
          child: Column(
            children: [
              // Header / User Profile Stub
              GlassContainer(
                width: double.infinity,
                padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
                child: Row(
                  children: [
                    Container(
                      width: Responsive.w(40),
                      height: Responsive.w(40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.black,
                        size: Responsive.w(24),
                      ),
                    ),
                    SizedBox(width: Responsive.w(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Royal Player',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: Responsive.sp(16),
                            ),
                          ),
                          Text(
                            'Level 12 • Duke',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: Responsive.sp(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                    ),
                  ],
                ),
              ),

              SizedBox(height: Responsive.h(AppDimens.paddingXL)),

              // Main Logo Area
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security,
                        size: Responsive.w(80),
                        color: AppColors.primary,
                      ),
                      SizedBox(height: Responsive.h(16)),
                      Text(
                        'BLUFFDEV',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: Responsive.sp(40),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Menu Buttons
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildMenuButton(
                      context,
                      'CREATE ROOM',
                      Icons.add_circle_outline,
                      () => Navigator.pushNamed(context, '/create_room'),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    _buildMenuButton(context, 'JOIN ROOM', Icons.login, () {
                      // For now, simpler flow: go to lobby or show a dialog (not implemented in phase 1)
                      // Assuming join leads to lobby for demo
                      Navigator.pushNamed(context, '/lobby');
                    }),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    _buildMenuButton(
                      context,
                      'PLAY WITH BOT',
                      Icons.smart_toy,
                      () {
                        Navigator.pushNamed(context, '/bot_settings');
                      },
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            context,
                            'DECK',
                            Icons.style,
                            () => Navigator.pushNamed(context, '/deck'),
                            isSmall: true,
                          ),
                        ),
                        SizedBox(width: Responsive.w(AppDimens.paddingM)),
                        Expanded(
                          child: _buildMenuButton(
                            context,
                            'RULES',
                            Icons.menu_book,
                            () => Navigator.pushNamed(context, '/rules'),
                            isSmall: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool isSmall = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isSmall ? Responsive.h(50) : Responsive.h(60),
      child: PrimaryButton(
        label: label,
        icon: icon,
        type: isSmall ? ButtonType.secondary : ButtonType.primary,
        onPressed: onPressed,
      ),
    );
  }
}
