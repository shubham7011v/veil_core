import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/unit.dart';

class BluffRevealOverlay extends StatelessWidget {
  final List<Unit> cards;
  final UnitRank declaredRank;

  const BluffRevealOverlay({
    super.key,
    required this.cards,
    required this.declaredRank,
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
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.2),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: const Text(
                "BLUFF CALLED!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: [
                    BoxShadow(
                      color: Colors.red,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "CLAIMED: ${cards.length} × ${_getRankSymbol(declaredRank)}s",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: cards.map((card) {
                  final isMatch = card.rank == declaredRank;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOutBack,
                      builder: (context, value, child) {
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(value * math.pi),
                          alignment: Alignment.center,
                          child: value < 0.5
                              ? _buildBackFace()
                              : Transform(
                                  transform: Matrix4.identity()
                                    ..rotateY(math.pi),
                                  alignment: Alignment.center,
                                  child: _buildFrontFace(card, isMatch),
                                ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackFace() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white38, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.style, color: Colors.white10, size: 50),
      ),
    );
  }

  Widget _buildFrontFace(Unit card, bool isMatch) {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: isMatch ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMatch ? Colors.greenAccent : Colors.redAccent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isMatch
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getRankSymbol(card.rank),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            isMatch ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
            size: 32,
          ),
        ],
      ),
    );
  }
}
