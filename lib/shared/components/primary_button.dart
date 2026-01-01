import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/dimens.dart';
import 'animated_button.dart';

enum ButtonType { primary, secondary, danger }

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    // Colors
    Color backgroundColor;
    Color textColor;
    Color borderColor = Colors.transparent;

    switch (type) {
      case ButtonType.primary:
        backgroundColor = AppColors.primary;
        textColor = Colors.black;
        break;
      case ButtonType.secondary:
        backgroundColor = AppColors.surface;
        textColor = AppColors.textPrimary;
        borderColor = AppColors.primaryDim;
        break;
      case ButtonType.danger:
        backgroundColor = AppColors.danger.withValues(alpha: 0.2);
        textColor = AppColors.danger;
        borderColor = AppColors.danger;
        break;
    }

    if (isDisabled) {
      backgroundColor = backgroundColor.withValues(alpha: 0.4);
      textColor = textColor.withValues(alpha: 0.4);
      borderColor = borderColor.withValues(alpha: 0.4);
    }

    // The visual container of the button
    final Widget buttonContent = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingL),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        border: Border.all(color: borderColor),
        boxShadow: (type == ButtonType.primary && !isDisabled)
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: textColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );

    // If disabled, just return the container to show disabled state, no interaction
    if (isDisabled) {
      return buttonContent;
    }

    // Wrap with AnimatedButton for interaction
    return AnimatedButton(onPressed: onPressed, child: buttonContent);
  }
}
