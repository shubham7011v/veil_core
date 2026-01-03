import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import '../../../../core/engine/engine.dart';
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
    final roundStatus = state.roundStatus;

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
        if (!state.isRoundSet && state.isMyTurn) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "SELECT RANK",
                style: TextStyle(
                  color: Color(0xFFE5A043),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: spacing,
                runSpacing: spacing * 0.6,
                alignment: WrapAlignment.center,
                children: ranks.map((rank) {
                  final isStaged = state.stagedRank == rank;
                  final buttonSize = (width - 48 - (spacing * 4)) / 5;
                  return GestureDetector(
                    onTap: () => bloc.add(RankStaged(rank)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: buttonSize,
                      height: buttonSize * 1.1,
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
                        borderRadius: BorderRadius.circular(10),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                "TAP TO DISMISS",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
