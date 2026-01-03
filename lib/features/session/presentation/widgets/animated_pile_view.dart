import 'package:flutter/material.dart';

class AnimatedPileView extends StatelessWidget {
  final GlobalKey? pileKey;
  final int pileCount;
  final String roundStatus;
  final bool isShuffling;
  final double width;
  final double height;
  final VoidCallback onTap;

  const AnimatedPileView({
    super.key,
    this.pileKey,
    required this.pileCount,
    required this.roundStatus,
    required this.isShuffling,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rank Status at Top Center
            Positioned(
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A043).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFFE5A043).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  roundStatus,
                  style: const TextStyle(
                    color: Color(0xFFE5A043),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

            // Visual pile indicator with count
            Container(
              key: pileKey,
              width: 90,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isShuffling)
                    const CircularProgressIndicator(
                      color: Color(0xFFE5A043),
                      strokeWidth: 2,
                    )
                  else ...[
                    Text(
                      pileCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      "CARDS",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
