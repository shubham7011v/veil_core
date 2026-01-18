import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/matchmaking_bloc.dart';
import '../bloc/matchmaking_event.dart';

class MatchmakingTimeoutDialog extends StatelessWidget {
  final AppColorPalette palette;
  final MatchmakingBloc bloc;

  const MatchmakingTimeoutDialog({
    super.key,
    required this.palette,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        '15 Seconds Remaining!',
        style: TextStyle(color: palette.primary, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'The lobby will auto-fill with bots soon. Do you want to keep waiting?',
        style: TextStyle(color: palette.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            bloc.add(CancelMatchmaking());
            Navigator.pop(context); // Close screen
          },
          child: Text('Leave', style: TextStyle(color: palette.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Wait', style: TextStyle(color: palette.primary)),
        ),
      ],
    );
  }
}

// Static helper to show the dialog
void showMatchmakingTimeoutDialog(
  BuildContext context,
  AppColorPalette palette,
  MatchmakingBloc bloc,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        MatchmakingTimeoutDialog(palette: palette, bloc: bloc),
  );
}
