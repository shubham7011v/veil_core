import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/constants/dimens.dart';
import 'settings_components.dart';

class SettingsAppearanceSection extends StatelessWidget {
  final AppColorPalette palette;
  final ThemeState themeState;
  final ValueChanged<AppThemeMode> onThemeChanged;

  const SettingsAppearanceSection({
    super.key,
    required this.palette,
    required this.themeState,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      palette: palette,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Theme',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: AppThemeMode.values.map((mode) {
                    final isSelected = themeState.mode == mode;
                    final modePalette = AppColors.getPalette(mode);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => onThemeChanged(mode),
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? palette.primary
                                  : palette.divider,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: modePalette.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: modePalette.divider,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: modePalette.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mode.name.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? palette.primary
                                      : palette.textSecondary,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
