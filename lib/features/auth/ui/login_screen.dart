
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/glass_container.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.w(AppDimens.paddingL)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Header
                GlassContainer(
                   width: Responsive.w(120),
                   height: Responsive.w(120),
                   borderRadius: 100,
                   child: Center(
                     child: Icon(Icons.security, size: Responsive.w(60), color: AppColors.primary),
                   ),
                ),
                SizedBox(height: Responsive.h(AppDimens.paddingXL)),
                
                Text(
                  'Welcome to the\nRoyal Court',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: Responsive.sp(32),
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: Responsive.h(8)),
                Text(
                  'Enter the realm of deception and prestige.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: Responsive.sp(14),
                  ),
                ),
                SizedBox(height: Responsive.h(48)),

                // Form
                _buildInput(context, 'USERNAME OR EMAIL', 'Enter your royal alias', Icons.person),
                SizedBox(height: Responsive.h(AppDimens.paddingL)),
                _buildInput(context, 'PASSWORD', 'Enter your secret key', Icons.visibility_off, isPassword: true),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primaryDim)),
                  ),
                ),
                
                SizedBox(height: Responsive.h(AppDimens.paddingL)),
                
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'LOGIN',
                    onPressed: () {
                      // Navigate to Home
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                  ),
                ),
                
                SizedBox(height: Responsive.h(AppDimens.paddingXL)),
                Text(
                  'OR CONTINUE WITH',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: Responsive.sp(12)),
                ),
                SizedBox(height: Responsive.h(AppDimens.paddingL)),
                
                Row(
                  children: [
                    Expanded(child: _buildSocialButton('Google', Icons.circle)), 
                    SizedBox(width: Responsive.w(AppDimens.paddingM)),
                    Expanded(child: _buildSocialButton('Apple', Icons.apple)),
                  ],
                ),
                
                SizedBox(height: Responsive.h(AppDimens.paddingXL)),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New Player? ', style: TextStyle(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Create Royal Account',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, String label, String hint, IconData suffixIcon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: Responsive.sp(12),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: Responsive.h(8)),
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
            border: Border.all(color: AppColors.primaryDim.withOpacity(0.3)),
          ),
          child: TextField(
            obscureText: isPassword,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.w(AppDimens.paddingM),
                vertical: Responsive.h(AppDimens.paddingM),
              ),
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              border: InputBorder.none,
              suffixIcon: Icon(suffixIcon, color: AppColors.primaryDim, size: Responsive.w(24)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(String label, IconData icon) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: Responsive.w(20), color: AppColors.textPrimary),
          SizedBox(width: Responsive.w(8)),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
