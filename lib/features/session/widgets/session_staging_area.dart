import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import 'unit_card.dart';

class SessionStagingArea extends StatelessWidget {
  final SessionBlocState state;
  final GlobalKey myAvatarKey;

  const SessionStagingArea({
    super.key,
    required this.state,
    required this.myAvatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final selectedUnits = state.engineState.myHand
        .where((u) => state.selectedUnitIds.contains(u.id))
        .toList();

    return SizedBox(
      key: myAvatarKey,
      height: 75,
      child: selectedUnits.isEmpty
          ? const SizedBox.shrink()
          : Center(
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(selectedUnits.length, (index) {
                  final unit = selectedUnits[index];
                  const double overlap = 30.0;
                  final double totalWidth =
                      70 + (selectedUnits.length - 1) * overlap;
                  final double startX = -(totalWidth / 2) + 35;

                  return Positioned(
                    left:
                        (MediaQuery.of(context).size.width / 2) +
                        startX +
                        (index * overlap) -
                        35,
                    child: UnitCard(
                      unit: unit,
                      onTap: () => bloc.add(UnitToggled(unit.id)),
                      isSelected: true,
                      width: 50,
                      height: 70,
                    ),
                  );
                }),
              ),
            ),
    );
  }
}
