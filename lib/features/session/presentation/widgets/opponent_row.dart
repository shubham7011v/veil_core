import 'package:flutter/material.dart';
import '../bloc/session_state.dart';
import 'participant_avatar.dart';

class OpponentRow extends StatelessWidget {
  final SessionBlocState state;
  final Map<String, GlobalKey> avatarKeys;

  const OpponentRow({super.key, required this.state, required this.avatarKeys});

  List<dynamic> _getOrderedOpponents() {
    final allParticipants = state.engineState.participants;
    final meIndex = allParticipants.indexWhere((p) => p.isMe);

    List<dynamic> opponents;
    if (meIndex == -1) {
      // Spectator or error: just show everyone else
      opponents = allParticipants.where((p) => !p.isMe).toList();
    } else {
      // Circular sort: Start after 'Me', go to end, then wrap around to start
      final afterMe = allParticipants.sublist(meIndex + 1);
      final beforeMe = allParticipants.sublist(0, meIndex);
      opponents = [...afterMe, ...beforeMe];
    }

    // Ensure uniqueness by ID to prevent GlobalKey collisions
    final seenIds = <String>{};
    final uniqueOpponents = opponents
        .where((p) => seenIds.add(p.id))
        .take(4)
        .toList();

    return uniqueOpponents;
  }

  @override
  Widget build(BuildContext context) {
    final opponents = _getOrderedOpponents();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: opponents.map((p) {
            return Flexible(
              child: ParticipantAvatar(
                key: avatarKeys[p.id],
                participant: p,
                size: 60,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
