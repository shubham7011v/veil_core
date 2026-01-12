import 'package:flutter/material.dart';
import 'session_history_list.dart';
import '../../domain/models/match_stats.dart';

class GameWinOverlay extends StatelessWidget {
  final String winnerId;
  final String winnerName;
  final int coinsEarned;
  final List<String> gameLog;
  final MatchStats matchStats;
  final VoidCallback onBackToHome;
  final VoidCallback? onPlayAgain;

  const GameWinOverlay({
    super.key,
    required this.winnerId,
    required this.winnerName,
    required this.coinsEarned,
    required this.gameLog,
    required this.matchStats,
    required this.onBackToHome,
    this.onPlayAgain,
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
          const SizedBox(height: 24),
          // Coins Earned/Lost
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: coinsEarned >= 0
                    ? const Color(0xFFFFD700)
                    : Colors.redAccent.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  coinsEarned >= 0 ? Icons.add_circle : Icons.remove_circle,
                  color: coinsEarned >= 0
                      ? const Color(0xFFFFD700)
                      : Colors.redAccent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  "${coinsEarned >= 0 ? '+' : ''}$coinsEarned",
                  style: TextStyle(
                    color: coinsEarned >= 0
                        ? const Color(0xFFFFD700)
                        : Colors.redAccent,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "coins",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Match Statistics
          if (matchStats.totalTurns > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatItem(
                    icon: Icons.refresh,
                    label: 'Turns',
                    value: '${matchStats.totalTurns}',
                  ),
                  const SizedBox(width: 24),
                  _StatItem(
                    icon: Icons.gavel,
                    label: 'Challenges',
                    value: '${matchStats.totalChallenges}',
                  ),
                  const SizedBox(width: 24),
                  _StatItem(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: matchStats.formattedDuration,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Match History Button
          TextButton.icon(
            onPressed: () => _showMatchHistory(context),
            icon: const Icon(Icons.history, color: Color(0xFFFFD700), size: 20),
            label: const Text(
              "VIEW MATCH HISTORY",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onPlayAgain != null)
                SizedBox(
                  width: 160,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "PLAY AGAIN",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              if (onPlayAgain != null) const SizedBox(width: 16),
              SizedBox(
                width: 160,
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
                    "HOME",
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
        ],
      ),
    );
  }

  void _showMatchHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "MATCH LOG",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SessionHistoryList(gameLog: gameLog),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for stat display
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}
