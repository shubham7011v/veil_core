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
    // Show cards selected by me
    final stagedUnits = state.engineState.myHand
        .where((u) => state.selectedUnitIds.contains(u.id))
        .toList();

    if (stagedUnits.isEmpty) {
      return const SizedBox(height: 100);
    }

    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: stagedUnits
            .map(
              (u) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: UnitCard(
                  unit: u,
                  isSelected: true,
                  onTap: () => bloc.add(UnitToggled(u.id)),
                  width: 60,
                  height: 85,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
