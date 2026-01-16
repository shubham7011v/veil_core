import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../managers/card_animation_manager.dart';
import '../managers/turn_popup_manager.dart';

/// Handles navigation and room-leaving logic for the Session Screen
class NavigationHandler {
  final BuildContext context;
  final void Function(VoidCallback fn) setState;
  final CardAnimationManager cardAnimations;
  final TurnPopupManager turnPopups;
  final List<dynamic> activeEmojis;
  final bool Function() isWebSocket;

  bool _isNavigating = false;

  NavigationHandler({
    required this.context,
    required this.setState,
    required this.cardAnimations,
    required this.turnPopups,
    required this.activeEmojis,
    required this.isWebSocket,
  });

  bool get isNavigating => _isNavigating;

  /// Show the "Leave Game" confirmation dialog
  Future<bool?> showLeaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Leave Game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave the game?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  /// Clean up and leave the game
  Future<void> leaveGame(String routeName) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    // ✅ FORCE LEAVE: Explicitly tell server to remove us immediately
    if (isWebSocket()) {
      try {
        AppLogger.sessionEvent('Manual exit - sending LEAVE_ROOM');
        di.sl.webSocketSessionHandler.leaveRoom('');
        // Add small delay to allow message to hit network buffer
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        AppLogger.sessionError('Failed to send LEAVE_ROOM', exception: e);
      }
    }

    // ✅ Cleanup local state
    cardAnimations.dispose();
    activeEmojis.clear();
    turnPopups.dispose();

    if (!context.mounted) return;
    context.read<SessionBloc>().add(const SessionResetRequested());
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }
}
