import 'package:flutter/material.dart';
import '../../domain/models/match_stats.dart';
import 'session_history_list.dart';

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
    final isWin = isMe;

    // Theme Colors
    const goldColor = Color(0xFFE5A043);
    const winColor = goldColor;
    const lossColor = Color(0xFFB71C1C);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85)),
        child: BackdropFilter(
          filter: const ColorFilter.mode(
            Colors.black,
            BlendMode.softLight,
          ), // subtle overlay
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title Section
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Icon(
                          isWin
                              ? Icons.emoji_events
                              : Icons.sentiment_dissatisfied,
                          color: isWin ? winColor : Colors.white24,
                          size: 100,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    isWin ? "YOU WON!" : "GAME OVER",
                    style: TextStyle(
                      fontFamily:
                          'Roboto', // Fallback, assume app has custom font
                      color: isWin ? Colors.white : Colors.white70,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: isWin
                          ? [
                              Shadow(
                                color: winColor.withValues(alpha: 0.6),
                                blurRadius: 20,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isWin ? "DECK MASTER" : "$winnerName VICTORIOUS",
                    style: TextStyle(
                      color: isWin ? goldColor : Colors.white38,
                      fontSize: 16,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Coins Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: coinsEarned >= 0
                            ? goldColor.withValues(alpha: 0.5)
                            : lossColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: coinsEarned >= 0
                              ? goldColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          coinsEarned >= 0
                              ? Icons.add_circle
                              : Icons.remove_circle,
                          color: coinsEarned >= 0 ? goldColor : lossColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${coinsEarned >= 0 ? '+' : ''}$coinsEarned",
                          style: TextStyle(
                            color: coinsEarned >= 0 ? goldColor : lossColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "COINS",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Detailed Stats Grid
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                label: "SUCCESSFUL BLUFFS",
                                value: matchStats.successfulBluffs.toString(),
                                isImportant: true,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: "BLUFFS CAUGHT",
                                value: matchStats.bluffsCaught.toString(),
                                isImportant: true,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                label: "FALSE ALARMS",
                                value: matchStats.falseAlarms.toString(),
                                color: Colors.white54,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: "CAUGHT BY OTHERS",
                                value: matchStats.bluffsCaughtByOthers
                                    .toString(),
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                label: "TOTAL TURNS",
                                value: matchStats.totalTurns.toString(),
                                color: Colors.white54,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: "DURATION",
                                value: matchStats.formattedDuration,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Match History Button
                  TextButton(
                    onPressed: () => _showMatchHistory(context),
                    style: TextButton.styleFrom(
                      overlayColor: goldColor.withValues(alpha: 0.1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, color: goldColor, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "VIEW MATCH LOG",
                          style: TextStyle(
                            color: goldColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (onPlayAgain != null) ...[
                        _ActionButton(
                          label: "PLAY AGAIN",
                          color: const Color(0xFF43A047), // Distinctive green
                          icon: Icons.replay,
                          onPressed: onPlayAgain!,
                        ),
                        const SizedBox(width: 16),
                      ],
                      _ActionButton(
                        label: "HOME",
                        color: goldColor,
                        icon: Icons.home_filled,
                        onPressed: onBackToHome,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMatchHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "MATCH LOG",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SessionHistoryList(gameLog: gameLog),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isImportant;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    this.isImportant = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? (isImportant ? Colors.white : Colors.white70),
            fontSize: isImportant ? 28 : 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isImportant ? const Color(0xFFE5A043) : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? color : Colors.transparent,
          foregroundColor: isPrimary ? Colors.black : color,
          elevation: isPrimary ? 8 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: isPrimary
              ? null
              : BorderSide(color: color.withValues(alpha: 0.5), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: isPrimary ? color.withValues(alpha: 0.4) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
