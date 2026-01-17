import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/engine/engine.dart';

class MatchmakingConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;
  final AnimationController pulseController;

  const MatchmakingConnectionBanner({
    super.key,
    required this.status,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected) return const SizedBox.shrink();

    final isReconnecting =
        status == ConnectionStatus.reconnecting ||
        status == ConnectionStatus.connecting;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: double.infinity,
        color: isReconnecting ? Colors.orangeAccent : Colors.redAccent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReconnecting ? Icons.sync : Icons.error_outline,
              color: Colors.black,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              isReconnecting ? 'Reconnecting to server...' : 'Connection Lost',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
