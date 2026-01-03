import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import '../../../../core/engine/engine.dart';
import 'unit_card.dart';

class SessionHandView extends StatelessWidget {
  final SessionBlocState state;
  final GlobalKey myAvatarKey;

  const SessionHandView({
    super.key,
    required this.state,
    required this.myAvatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final displayHand = state.engineState.myHand
        .where((u) => !state.selectedUnitIds.contains(u.id))
        .toList();

    if (displayHand.isEmpty) {
      return SizedBox(
        key: myAvatarKey,
        height: 150,
        child: const Center(
          child: Text("EMPTY HAND", style: TextStyle(color: Colors.white24)),
        ),
      );
    }

    return SizedBox(
      key: myAvatarKey,
      height: 150,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final int mid = (displayHand.length / 2).floor();
          final backRow = displayHand.sublist(0, mid);
          final frontRow = displayHand.sublist(mid);

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (backRow.isNotEmpty)
                Positioned(
                  bottom: 35,
                  child: _buildRowContent(context, backRow, state, width),
                ),
              Positioned(
                bottom: 0,
                child: _buildRowContent(context, frontRow, state, width),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRowContent(
    BuildContext context,
    List<Unit> rowItems,
    SessionBlocState state,
    double maxWidth,
  ) {
    final bloc = context.read<SessionBloc>();
    final fullHand = state.engineState.myHand;
    const double cardWidth = 70;
    const double overlap = 28;

    return SizedBox(
      height: 110,
      width: maxWidth,
      child: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            buildDefaultDragHandles: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: rowItems.length,
            onReorder: (oldIndex, newIndex) {
              final unitToMove = rowItems[oldIndex];
              final absoluteOldIndex = fullHand.indexWhere(
                (u) => u.id == unitToMove.id,
              );

              int absoluteNewIndex;
              if (newIndex >= rowItems.length) {
                final lastUnitInRow = rowItems.last;
                absoluteNewIndex =
                    fullHand.indexWhere((u) => u.id == lastUnitInRow.id) + 1;
              } else {
                final targetUnit = rowItems[newIndex];
                absoluteNewIndex = fullHand.indexWhere(
                  (u) => u.id == targetUnit.id,
                );
              }

              if (absoluteOldIndex != -1) {
                bloc.add(
                  HandReorderRequested(absoluteOldIndex, absoluteNewIndex),
                );
              }
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.1,
                    child: Material(color: Colors.transparent, child: child),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final unit = rowItems[index];
              return SizedBox(
                key: ValueKey(unit.id),
                width: index == rowItems.length - 1 ? cardWidth : overlap,
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
    );
  }
}
