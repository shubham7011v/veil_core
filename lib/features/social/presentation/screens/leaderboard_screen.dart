import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/auth.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../session/session.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  WebSocketSessionHandler? _handler;

  @override
  void initState() {
    super.initState();
    // Get handler from SessionBloc
    final bloc = context.read<SessionBloc>();
    if (bloc.handler is WebSocketSessionHandler) {
      _handler = bloc.handler as WebSocketSessionHandler;
      _handler?.requestLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'GLOBAL RANKINGS',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFE5A043),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _handler == null
          ? const Center(
              child: Text(
                'Connect to Multiplayer to see rankings',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : StreamBuilder<List<UserStats>>(
              stream: _handler!.leaderboardStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE5A043)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final players = snapshot.data ?? [];

                if (players.isEmpty) {
                  return const Center(
                    child: Text(
                      'No rankings available yet',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return _buildLeaderboardTile(index + 1, player);
                  },
                );
              },
            ),
    );
  }

  Widget _buildLeaderboardTile(int rank, UserStats player) {
    final bool isTop3 = rank <= 3;
    final Color rankColor = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // Silver
        : rank == 3
        ? const Color(0xFFCD7F32) // Bronze
        : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3 ? rankColor.withValues(alpha: 0.3) : Colors.white10,
          width: isTop3 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: GoogleFonts.cinzel(
                color: rankColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE5A043).withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: Color(0xFFE5A043), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  player.rank.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.wins} WINS',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFE5A043),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${player.winRate.toStringAsFixed(1)}% WR',
                style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
