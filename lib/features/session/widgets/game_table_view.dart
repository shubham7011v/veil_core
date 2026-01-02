import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import '../models/unit.dart';
import 'animated_pile_view.dart';

class GameTableView extends StatelessWidget {
  final SessionBlocState state;
  final GlobalKey pileKey;

  const GameTableView({super.key, required this.state, required this.pileKey});

  @override
  Widget build(BuildContext context) {
    if (state.shouldShowRankSelector) {
      return _buildRankSelector(context);
    }

    return _buildCenterPile(context);
  }

  Widget _buildCenterPile(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final handler = bloc.handler;
    final currentRank = handler.lastMove?.declaredRank ?? state.stagedRank;
    final rankName = currentRank?.name.toUpperCase() ?? "???";
    final isRoundSet = handler.lastMove != null;
    final roundStatus = isRoundSet ? "${rankName}S" : "WAITING";

    return AnimatedPileView(
      pileKey: pileKey,
      pileCount: state.engineState.pileCount,
      roundStatus: roundStatus,
      onTap: () {
        if (!isRoundSet && state.isMyTurn) {
          bloc.add(RankSelectionToggleRequested());
        }
      },
    );
  }

  Widget _buildRankSelector(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "SELECT ROUND RANK",
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: ranks.map((rank) {
                final isStaged = state.stagedRank == rank;
                return GestureDetector(
                  onTap: () => bloc.add(RankStaged(rank)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isStaged
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isStaged ? Colors.white : Colors.white10,
                        width: 1.0,
                      ),
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
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => bloc.add(RankSelectionToggleRequested()),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
