import 'package:flutter/material.dart';
import '../../domain/models/match_history_item.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchHistoryList extends StatelessWidget {
  final List<MatchHistoryItem> history;
  final String currentUserId;

  const MatchHistoryList({
    super.key,
    required this.history,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No recent matches",
            style: GoogleFonts.inter(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: history.length,
      itemBuilder: (context, index) {
        final match = history[index];
        final isWin = match.winnerId == currentUserId;
        final dateStr = DateFormat('MMM d, h:mm a').format(match.playedAt);

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: ListTile(
            leading: Icon(
              isWin ? Icons.emoji_events : Icons.close,
              color: isWin ? Colors.amber : Colors.redAccent,
            ),
            title: Text(
              isWin ? "Victory" : "Defeat",
              style: GoogleFonts.cinzel(
                color: isWin ? Colors.amber : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              dateStr,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isWin ? '+' : ''}${match.potAmount} 🪙",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
