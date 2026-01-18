import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/matchmaking_bloc.dart';
import '../bloc/matchmaking_event.dart';

class MatchmakingTimeoutDialog extends StatefulWidget {
  final AppColorPalette palette;
  final MatchmakingBloc bloc;

  const MatchmakingTimeoutDialog({
    super.key,
    required this.palette,
    required this.bloc,
  });

  @override
  State<MatchmakingTimeoutDialog> createState() =>
      _MatchmakingTimeoutDialogState();
}

class _MatchmakingTimeoutDialogState extends State<MatchmakingTimeoutDialog> {
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.palette.surface,
      title: Text(
        '15 Seconds Remaining!',
        style: TextStyle(
          color: widget.palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The lobby will auto-fill with bots soon. Do you want to keep waiting?',
            style: TextStyle(color: widget.palette.textPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'Closing in $_secondsRemaining seconds...',
            style: TextStyle(
              color: widget.palette.textTertiary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            widget.bloc.add(CancelMatchmaking());
            Navigator.pop(context); // Close screen
          },
          child: Text('Leave', style: TextStyle(color: widget.palette.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Wait', style: TextStyle(color: widget.palette.primary)),
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
