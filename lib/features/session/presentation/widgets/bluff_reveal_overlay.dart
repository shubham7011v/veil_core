import 'package:flutter/material.dart';
import '../../../../core/engine/engine.dart';
import 'unit_card.dart';

class BluffRevealOverlay extends StatelessWidget {
  final List<Unit> cards;
  final UnitRank declaredRank;

  const BluffRevealOverlay({
    super.key,
    required this.cards,
    required this.declaredRank,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBluff = cards.any((c) => c.rank != declaredRank);

    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isBluff ? "BLUFF DETECTED!" : "NO BLUFF!",
              style: TextStyle(
                color: isBluff ? Colors.red : Colors.green,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "DECLARED: ${declaredRank.name.toUpperCase()}S",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: cards
                    .map(
                      (u) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: UnitCard(
                          onTap: () {},
                          unit: u,
                          isSelected: false,
                          isRevealed: true,
                          highlightError: u.rank != declaredRank,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 60),
            const Text(
              "RESOLVING...",
              style: TextStyle(
                color: Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
