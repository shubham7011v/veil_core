import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';

class InsufficientCoinsDialog extends StatelessWidget {
  final AppColorPalette palette;
  final VoidCallback? onOk;

  const InsufficientCoinsDialog({super.key, required this.palette, this.onOk});

  static Future<void> show({
    required BuildContext context,
    required AppColorPalette palette,
    VoidCallback? onOk,
  }) {
    return showDialog(
      context: context,
      builder: (context) =>
          InsufficientCoinsDialog(palette: palette, onOk: onOk),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        'Insufficient Coins',
        style: GoogleFonts.cinzel(color: palette.danger),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You need at least 100 coins to play online.',
            style: GoogleFonts.inter(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            'Watch ads or complete daily challenges to earn more!',
            style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOk?.call();
          },
          child: Text('OK', style: TextStyle(color: palette.primary)),
        ),
      ],
    );
  }
}
