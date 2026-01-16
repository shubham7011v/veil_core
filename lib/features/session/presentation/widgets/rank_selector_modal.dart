import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/engine/engine.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';

class RankSelectorModal extends StatelessWidget {
  final SessionBlocState state;

  const RankSelectorModal({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.shouldShowRankSelector) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 105),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: const Color(0xFFE5A043).withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(1), // Border width
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE5A043),
                        Colors.white10,
                        Colors.white10,
                        Color(0xFFC48B30),
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with subtle glow
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFE5A043), Color(0xFFFEEDD8)],
                          ).createShader(bounds),
                          child: const Text(
                            "SELECT ROUND RANK",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Rank Grid
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: UnitRank.values.map((rank) {
                            final isStaged = state.stagedRank == rank;
                            return _RankButton(
                              rank: rank,
                              isStaged: isStaged,
                              onTap: () {
                                context.read<SessionBloc>().add(
                                  RankStaged(rank),
                                );
                              },
                            );
                          }).toList(),
                        ),

                        if (state.stagedRank != null) ...[
                          const SizedBox(height: 16),
                          _ConfirmButton(
                            onPressed: () {
                              context.read<SessionBloc>().add(
                                RankSelectionToggleRequested(),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankButton extends StatelessWidget {
  final UnitRank rank;
  final bool isStaged;
  final VoidCallback onTap;

  const _RankButton({
    required this.rank,
    required this.isStaged,
    required this.onTap,
  });

  String _getRankSymbol(UnitRank rank) {
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
        return (rank.index + 2).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isStaged
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE5A043), Color(0xFFC48B30)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
          border: Border.all(
            color: isStaged
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: isStaged
              ? [
                  BoxShadow(
                    color: const Color(0xFFE5A043).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            _getRankSymbol(rank),
            style: TextStyle(
              color: isStaged ? Colors.black : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              shadows: isStaged
                  ? []
                  : [const Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ConfirmButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFE5A043), Color(0xFFC48B30)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE5A043).withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "CONFIRM SELECTION",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
