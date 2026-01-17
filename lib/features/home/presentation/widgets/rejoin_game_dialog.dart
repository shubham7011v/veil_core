import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';

class RejoinGameDialog extends StatelessWidget {
  final AppColorPalette palette;
  final VoidCallback onResume;
  final VoidCallback onNewGame;

  const RejoinGameDialog({
    super.key,
    required this.palette,
    required this.onResume,
    required this.onNewGame,
  });

  static Future<void> show({
    required BuildContext context,
    required AppColorPalette palette,
    required VoidCallback onResume,
    required VoidCallback onNewGame,
  }) {
    return showDialog(
      context: context,
      builder: (context) => RejoinGameDialog(
        palette: palette,
        onResume: onResume,
        onNewGame: onNewGame,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        'Active Game Found',
        style: GoogleFonts.cinzel(color: palette.textPrimary),
      ),
      content: Text(
        'You are currently in an active game session. Do you want to rejoin it or start a new game?',
        style: GoogleFonts.inter(color: palette.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            onNewGame();
          },
          child: Text('New Game', style: TextStyle(color: palette.danger)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            onResume();
          },
          child: const Text('Resume Game'),
        ),
      ],
    );
  }
}
