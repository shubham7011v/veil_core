import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/auth.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../session/session.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';

class LeaderboardScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const LeaderboardScreen({super.key, this.onBack});

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
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'GLOBAL RANKINGS',
              style: GoogleFonts.cinzel(
                color: palette.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: palette.textSecondary),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: _handler == null
              ? Center(
                  child: Text(
                    'Connect to Multiplayer to see rankings',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                )
              : StreamBuilder<List<UserStats>>(
                  stream: _handler!.leaderboardStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: palette.primary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: palette.danger),
                        ),
                      );
                    }

                    final players = snapshot.data ?? [];

                    if (players.isEmpty) {
                      return Center(
                        child: Text(
                          'No rankings available yet',
                          style: TextStyle(color: palette.textTertiary),
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
                        return _buildLeaderboardTile(
                          index + 1,
                          player,
                          palette,
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildLeaderboardTile(
    int rank,
    UserStats player,
    AppColorPalette palette,
  ) {
    final bool isTop3 = rank <= 3;
    final Color rankColor = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // Silver
        : rank == 3
        ? const Color(0xFFCD7F32) // Bronze
        : palette.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3 ? rankColor.withValues(alpha: 0.3) : palette.divider,
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
            backgroundColor: palette.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: palette.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: GoogleFonts.inter(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  player.rank.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: palette.textTertiary,
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
                  color: palette.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${player.winRate.toStringAsFixed(1)}% WR',
                style: GoogleFonts.inter(
                  color: palette.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
