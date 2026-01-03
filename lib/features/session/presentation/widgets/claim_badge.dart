import 'package:flutter/material.dart';
import '../../../../core/engine/engine.dart';

class ClaimBadge extends StatelessWidget {
  final GameMove lastMove;

  const ClaimBadge({super.key, required this.lastMove});

  @override
  Widget build(BuildContext context) {
    final rankSymbol = _getRankSymbol(lastMove.declaredRank);
    final count = lastMove.actualUnits.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5A043), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5A043).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: Colors.white24),
          const SizedBox(width: 8),
          Text(
            rankSymbol,
            style: const TextStyle(
              color: Color(0xFFE5A043),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            "s",
            style: TextStyle(
              color: Color(0xFFE5A043),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

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
}
