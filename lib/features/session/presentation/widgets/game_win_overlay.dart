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
    final bool isMe = winnerId == 'me';

    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFE5A043), size: 100),
          const SizedBox(height: 24),
          Text(
            isMe ? "YOU WON!" : "GAME OVER",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMe ? "DECK MASTER" : "$winnerName VICTORIOUS",
            style: TextStyle(
              color: isMe ? const Color(0xFFE5A043) : Colors.white54,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 60),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: onBackToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A043),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "BACK TO COURT",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
