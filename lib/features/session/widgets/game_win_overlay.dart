import 'package:flutter/material.dart';

class GameWinOverlay extends StatelessWidget {
  final String winnerId;
  final String winnerName;
  final VoidCallback onBackToHome;

  const GameWinOverlay({
    super.key,
    required this.winnerId,
    required this.winnerName,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = winnerId == 'me';

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMe ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
              size: 100,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(height: 24),
            Text(
              isMe ? "VICTORY!" : "GAME OVER",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMe
                  ? "You have cleared all your cards!"
                  : "$winnerName has won the game.",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton(
                onPressed: onBackToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  "BACK TO HOME",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
