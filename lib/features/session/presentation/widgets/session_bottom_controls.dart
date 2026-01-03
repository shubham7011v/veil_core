import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import '../../../../core/engine/engine.dart';
import 'unit_card.dart';

class SessionBottomControls extends StatelessWidget {
  final SessionBlocState state;
  final GlobalKey myAvatarKey;

  const SessionBottomControls({
    super.key,
    required this.state,
    required this.myAvatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final selectionCount = state.selectedUnitIds.length;
    final hasSelection = selectionCount > 0;
    final isMyTurn = state.isMyTurn;
    final isRoundSet = state.isRoundSet;
    final canSubmit = state.canSubmit;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.95),
            Colors.black,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anchor for flying cards animation
          SizedBox(
            height: 130,
            child: _buildHandArea(
              context,
              state.engineState.myHand
                  .where((u) => !state.selectedUnitIds.contains(u.id))
                  .toList(),
              state,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: isMyTurn
                        ? () => bloc.add(TurnPassRequested())
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "PASS",
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: canSubmit
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                          ),
                  ),
                  child: ElevatedButton(
                    onPressed: canSubmit
                        ? () => bloc.add(CardsPlayRequested())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      hasSelection ? "PLAY $selectionCount" : "PLAY",
                      style: TextStyle(
                        color: canSubmit ? Colors.black : Colors.white24,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (isRoundSet && isMyTurn)
                        ? () => bloc.add(ChallengeRaiseRequested())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRoundSet
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      "BLUFF",
                      style: TextStyle(
                        color: isRoundSet ? Colors.white : Colors.white10,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHandArea(
    BuildContext context,
    List<Unit> hand,
    SessionBlocState state,
  ) {
    if (hand.isEmpty) {
      return const Center(
        child: Text("EMPTY HAND", style: TextStyle(color: Colors.white24)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double cardWidth = 70;
        const double overlap = 25;

        if (hand.length <= 10) {
          return _buildRowContent(
            context,
            hand,
            state,
            width,
            cardWidth,
            overlap,
          );
        } else {
          final int mid = (hand.length / 2).ceil();
          final backRow = hand.sublist(0, mid);
          final frontRow = hand.sublist(mid);
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 30,
                child: _buildRowContent(
                  context,
                  backRow,
                  state,
                  width,
                  cardWidth,
                  overlap,
                ),
              ),
              Positioned(
                bottom: 0,
                child: _buildRowContent(
                  context,
                  frontRow,
                  state,
                  width,
                  cardWidth,
                  overlap,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildRowContent(
    BuildContext context,
    List<Unit> handSlice,
    SessionBlocState state,
    double maxWidth,
    double cardWidth,
    double overlap,
  ) {
    final bloc = context.read<SessionBloc>();
    final double scrollWidth = cardWidth + (handSlice.length - 1) * overlap;

    return SizedBox(
      height: 100,
      width: maxWidth,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: scrollWidth + 40, // padding for drag
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              itemCount: handSlice.length,
              onReorder: (oldIndex, newIndex) {
                bloc.add(HandReorderRequested(oldIndex, newIndex));
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (animation.value * 0.1),
                      child: Material(color: Colors.transparent, child: child),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final unit = handSlice[index];
                return SizedBox(
                  key: ValueKey(unit.id),
                  width: index == handSlice.length - 1 ? cardWidth : overlap,
                  child: OverflowBox(
                    maxWidth: cardWidth,
                    minWidth: cardWidth,
                    alignment: Alignment.centerLeft,
                    child: UnitCard(
                      unit: unit,
                      isSelected: false,
                      onTap: () => bloc.add(UnitToggled(unit.id)),
                      width: cardWidth,
                      height: 100,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
