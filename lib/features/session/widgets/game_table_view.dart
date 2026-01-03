import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import '../models/unit.dart';
import '../models/session_state.dart';
import 'animated_pile_view.dart';
import 'card_flip_view.dart';

class GameTableView extends StatelessWidget {
  final SessionBlocState state;
  final GlobalKey pileKey;

  const GameTableView({super.key, required this.state, required this.pileKey});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double finalWidth =
            constraints.maxWidth - 32; // Account for 16px padding on each side
        final double finalHeight = constraints.maxHeight;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CardFlipView(
            isFlipped: state.shouldShowRankSelector,
            front: _buildCenterPile(context, finalWidth, finalHeight),
            back: _buildRankSelector(context, finalWidth, finalHeight),
          ),
        );
      },
    );
  }

  Widget _buildCenterPile(BuildContext context, double width, double height) {
    final bloc = context.read<SessionBloc>();
    final handler = bloc.handler;
    final currentRank = handler.lastMove?.declaredRank ?? state.stagedRank;
    final rankName = currentRank?.name.toUpperCase() ?? "???";
    final isRoundSet = handler.lastMove != null;
    final roundStatus = isRoundSet ? "${rankName}S" : "WAITING";

    final isShuffling =
        state.engineState.currentPhase == SessionPhase.thinking &&
        state.engineState.pileCount == 0 &&
        (state.engineState.lastActionText?.contains("Shuffling") ?? false);

    return AnimatedPileView(
      pileKey: pileKey,
      pileCount: state.engineState.pileCount,
      roundStatus: roundStatus,
      isShuffling: isShuffling,
      width: width,
      height: height,
      onTap: () {
        if (!isRoundSet && state.isMyTurn) {
          bloc.add(RankSelectionToggleRequested());
        }
      },
    );
  }

  Widget _buildRankSelector(BuildContext context, double width, double height) {
    final bloc = context.read<SessionBloc>();
    final ranks = UnitRank.values.toList();

    String getRankSymbol(UnitRank rank) {
      switch (rank) {
        case UnitRank.ace:
          return "A";
        case UnitRank.jack:
          return "J";
        case UnitRank.queen:
          return "Q";
        case UnitRank.king:
          return "K";
        default:
          return (rank.index + 2).toString();
      }
    }

    // Scale spacing based on width to ensure they fit
    final spacing = (width * 0.03).clamp(8.0, 16.0);

    return GestureDetector(
      onTap: () => bloc.add(RankSelectionToggleRequested()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF1E1E1E), const Color(0xFF121212)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5A043).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "SELECT RANK",
              style: TextStyle(
                color: const Color(0xFFE5A043),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: ranks.map((rank) {
                final isStaged = state.stagedRank == rank;
                return GestureDetector(
                  onTap: () => bloc.add(RankStaged(rank)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width:
                        (width - 64 - (spacing * 4)) /
                        5, // Calculate width to fit 5 per row
                    height: ((width - 64 - (spacing * 4)) / 5) * 1.2,
                    decoration: BoxDecoration(
                      gradient: isStaged
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE5A043), Color(0xFFC48B30)],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.05),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isStaged
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                      boxShadow: isStaged
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFE5A043,
                                ).withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        getRankSymbol(rank),
                        style: TextStyle(
                          color: isStaged ? Colors.black : Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              "TAP TO DISMISS",
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
