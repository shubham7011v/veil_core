import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';
import 'session_hand_view.dart';

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
          // The "Deck" View
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isMyTurn
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: SessionHandView(state: state, myAvatarKey: myAvatarKey),
          ),

          const SizedBox(height: 8),

          // Action Buttons View
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
                      side: BorderSide(
                        color: isMyTurn
                            ? const Color(0xFF4CAF50)
                            : Colors.white24,
                        width: isMyTurn ? 1.5 : 1,
                      ),
                      backgroundColor: isMyTurn
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "PASS",
                      style: TextStyle(
                        color: isMyTurn
                            ? const Color(0xFF4CAF50)
                            : Colors.white54,
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
}
