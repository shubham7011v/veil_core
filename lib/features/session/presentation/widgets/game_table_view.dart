import 'package:flutter/material.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../bloc/session_state.dart';
import 'animated_pile_view.dart';

class GameTableView extends StatelessWidget {
  final SessionBlocState state;
  final GlobalKey pileKey;

  const GameTableView({super.key, required this.state, required this.pileKey});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double finalWidth = constraints.maxWidth - 32;
        final double finalHeight = constraints.maxHeight;

        final isShuffling =
            state.engineState.currentPhase == engine.SessionPhase.thinking &&
            (state.engineState.lastActionText?.contains("Shuffling") ?? false);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AnimatedPileView(
            pileKey: pileKey,
            pileCount: state.engineState.pileCount,
            roundStatus: state.roundStatus,
            isShuffling: isShuffling,
            width: finalWidth,
            height: finalHeight,
            onTap: () {
              // Tap logic can be added here if needed,
              // but rank selection is now modal.
            },
          ),
        );
      },
    );
  }
}
