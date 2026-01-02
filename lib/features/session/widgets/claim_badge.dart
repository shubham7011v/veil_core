import 'package:flutter/material.dart';
import '../models/unit.dart';

class ClaimBadge extends StatelessWidget {
  final UnitRank rank;
  final int count;
  final bool isTransferring;

  const ClaimBadge({
    super.key,
    required this.rank,
    required this.count,
    this.isTransferring = false,
  });

  String _getRankSymbol(UnitRank rank) {
    switch (rank) {
      case UnitRank.ace:
        return 'A';
      case UnitRank.king:
        return 'K';
      case UnitRank.queen:
        return 'Q';
      case UnitRank.jack:
        return 'J';
      case UnitRank.ten:
        return '10';
      case UnitRank.nine:
        return '9';
      case UnitRank.eight:
        return '8';
      case UnitRank.seven:
        return '7';
      case UnitRank.six:
        return '6';
      case UnitRank.five:
        return '5';
      case UnitRank.four:
        return '4';
      case UnitRank.three:
        return '3';
      case UnitRank.two:
        return '2';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isTransferring
              ? const Color(0xFFD32F2F).withValues(alpha: 0.9)
              : const Color(0xFF1976D2).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getRankSymbol(rank),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 8),
            Container(height: 20, width: 2, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              '×$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
