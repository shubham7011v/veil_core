import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import 'session_history_list.dart';
import 'doc_viewer.dart';
import '../../../../core/config/feature_flags.dart';

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
      builder: (context) => DocViewer(
        title: "GAME RULES",
        content:
            "Core Rules:\n- Standard 52-card deck. Suits are ignored.\n- Play 1-4 cards or Pass.\n- Only the NEXT player can call a Bluff.\n- Bluff correct (Lie) -> Liar picks pile.\n- Bluff wrong (Truth) -> Caller picks pile.\n\nPass-Cycle Rule:\n- If everyone passes and turn comes back to the last player:\n1. Entire pile is DISCARDED.\n2. That player starts a NEW round.",
      ),
    );
  }

  Widget _buildTimer(SessionBlocState state) {
    if (state.engineState.turnStartTime == null) {
      return const Text(
        "WAITING...",
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontFamily: 'Monospace',
        ),
      );
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final elapsed = now - state.engineState.turnStartTime!;
        final remaining = (25 - elapsed).clamp(0, 25);

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
