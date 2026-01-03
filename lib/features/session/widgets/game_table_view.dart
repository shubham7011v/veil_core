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
        // Responsible sizing: use the smaller of (width) or (height/aspectRatio)
        const double targetAspectRatio = 1.2;
        final double maxAvailableWidth = (constraints.maxWidth - 32).clamp(
          0.0,
          double.infinity,
        );
        final double maxAvailableHeight = (constraints.maxHeight - 20).clamp(
          0.0,
          double.infinity,
        );

        // Calculate theoretical width based on height constraint
        final double widthFromHeight = maxAvailableHeight / targetAspectRatio;

        // Final width is the smaller of available width, widthFromHeight, or a reasonable max
        final double finalWidth = widthFromHeight < maxAvailableWidth
            ? widthFromHeight.clamp(120.0, 400.0)
            : maxAvailableWidth.clamp(120.0, 400.0);

        final double finalHeight = finalWidth * targetAspectRatio;

        return CardFlipView(
          isFlipped: state.shouldShowRankSelector,
          front: _buildCenterPile(context, finalWidth, finalHeight),
          back: _buildRankSelector(context, finalWidth, finalHeight),
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
          return (rank.index + 1).toString();
      }
    }

    // Scale buttons based on the smallest dimension to ensure they fit
    final buttonSize = (width / 5.5).clamp(24.0, 48.0);
    final spacing = (width * 0.03).clamp(4.0, 12.0);

    return GestureDetector(
      onTap: () => bloc.add(RankSelectionToggleRequested()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
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
                color: const Color(0xFFFFD700),
                fontSize: (height * 0.06).clamp(10.0, 14.0),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: height * 0.03),
            Expanded(
              child: Center(
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.center,
                  children: ranks.map((rank) {
                    final isStaged = state.stagedRank == rank;
                    return GestureDetector(
                      onTap: () => bloc.add(RankStaged(rank)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: isStaged
                              ? const Color(0xFFFFD700)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isStaged ? Colors.white : Colors.white12,
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            getRankSymbol(rank),
                            style: TextStyle(
                              color: isStaged
                                  ? Colors.black
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: buttonSize * 0.45,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: height * 0.02),
            Text(
              "TAP TO FLIP BACK",
              style: TextStyle(
                color: Colors.white24,
                fontSize: (height * 0.04).clamp(8.0, 10.0),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
