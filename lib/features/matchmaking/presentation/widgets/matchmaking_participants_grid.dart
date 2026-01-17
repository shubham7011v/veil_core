import 'package:flutter/material.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/constants/game_constants.dart';
import 'participant_card.dart';
import 'empty_slot.dart';

class MatchmakingParticipantsGrid extends StatelessWidget {
  final List<Participant> participants;

  const MatchmakingParticipantsGrid({super.key, required this.participants});

  @override
  Widget build(BuildContext context) {
    final List<Participant> sorted = List.from(participants);
    sorted.sort((a, b) {
      if (a.isMe) return -1;
      if (b.isMe) return 1;
      return 0;
    });

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: GameConstants.playerGridCrossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: GameConstants.playerCardAspectRatio,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: GameConstants.maxPlayers,
      itemBuilder: (context, index) {
        if (index < sorted.length) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: ParticipantCard(
              key: ValueKey(sorted[index].id),
              participant: sorted[index],
            ),
          );
        }
        return const AnimatedSwitcher(
          duration: Duration(milliseconds: 500),
          child: EmptySlot(),
        );
      },
    );
  }
}
