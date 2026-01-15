import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import 'session_history_list.dart';
import 'doc_viewer.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/engine/engine.dart' as engine;

class SessionTopBar extends StatelessWidget {
  final SessionBlocState state;
  final VoidCallback onChatTap;

  const SessionTopBar({
    super.key,
    required this.state,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(icon: Icons.menu, onTap: () => _showGameMenu(context)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimer(state),
              const Text(
                "TIME REMAINING",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (FeatureFlags.enableGameChat)
            _CircleButton(icon: Icons.chat_bubble_outline, onTap: onChatTap)
          else
            const SizedBox(
              width: 40,
            ), // Placeholder to keep spacing or just empty
        ],
      ),
    );
  }

  void _showGameMenu(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFFFFD700)),
            title: const Text(
              "MATCH HISTORY",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showHistory(context);
            },
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.white70),
            title: const Text(
              "GAME RULES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRules(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sort, color: Colors.blueAccent),
            title: const Text(
              "SORT CARDS (ASC)",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              bloc.add(HandSortRequested());
            },
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text(
              "EXIT GAME",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              // Close menu first
              Navigator.pop(context);

              // Reset session to clean up state
              context.read<SessionBloc>().add(const SessionResetRequested());

              // Navigate home
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (r) => false);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
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
            const Text(
              "MATCH LOG",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SessionHistoryList(gameLog: state.gameLog),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
            const SizedBox(height: 16),
            const Text(
              "GAME RULES",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20.0),
                child: const DocViewer(
                  title: "",
                  content: """🎯 OBJECTIVE
Win by being the first to play all your cards!

📋 BASIC RULES
• 2-10 players, standard 52-card deck
• Suits ignored - only ranks matter
• Play 1-4 cards face-down per turn
• Declare a rank (can lie = bluff!)

🎴 PLAYING CARDS
1. First player chooses ANY rank
2. All others MUST match that rank
3. You can bluff (play different cards)
4. Next player can CHALLENGE or PASS

⚔️ CHALLENGING (CRITICAL!)
⚠️ ONLY THE NEXT PLAYER CAN CHALLENGE
• If bluff caught: Liar picks up pile
• If false alarm: Challenger picks up pile
• Winner of challenge starts next round

🚫 PASSING
• Can't/won't play or challenge? Pass!
• If EVERYONE passes → Pile discarded
• Last player starts new round

🏆 WINNING
• Play your last card to win
• Opponents get 1 chance to challenge
• If truth: You win!
• If bluff: Pick up pile, keep playing

⏱️ TURN TIMER (Online Only)
• 25 seconds per turn
• Auto-pass if time runs out

💡 STRATEGY TIPS
✅ Bluff when:
  - Close to winning (3-4 cards left)
  - Pile is small
  - Against conservative players

✅ Challenge when:
  - Opponent near winning
  - They played 3-4 cards
  - Pile is manageable size

✅ Pass when:
  - No matching cards
  - Don't want to bluff
  - Force pile discard

📊 EXAMPLE ROUND
Player 1: "2 Queens" (starts round)
Player 2: Must claim Queens or pass
Player 3: Challenges Player 2!
→ Cards revealed
  • Bluff: P2 picks up pile
  • Truth: P3 picks up pile
Winner starts new round

⚠️ REMEMBER
• Only NEXT player challenges
• Match round rank (or bluff)
• All pass = pile discarded
• First to 0 cards wins!

Good luck! May your bluffs be bold! 🎴✨""",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(SessionBlocState state) {
    if (state.engineState.turnStartTime == null) {
      // Show phase-specific status instead of generic "WAITING..."
      String status;
      Color statusColor;

      switch (state.engineState.currentPhase) {
        case engine.SessionPhase.lobby:
          status = "LOBBY";
          statusColor = const Color(0xFF4CAF50);
          break;
        case engine.SessionPhase.starting:
          status = "STARTING";
          statusColor = const Color(0xFFFFD700);
          break;
        default:
          status = "READY";
          statusColor = const Color(0xFF2196F3);
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          if (state.engineState.pileCount > 0)
            Text(
              "${state.engineState.pileCount} in pile",
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      );
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final elapsed = now - state.engineState.turnStartTime!;
        final remaining = (30 - elapsed).clamp(0, 30);

        return Text(
          "00:${remaining.toString().padLeft(2, '0')}",
          style: TextStyle(
            color: remaining <= 5 ? Colors.redAccent : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: 'Monospace',
          ),
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
