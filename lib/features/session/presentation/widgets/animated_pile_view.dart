import 'package:flutter/material.dart';

class AnimatedPileView extends StatelessWidget {
  final GlobalKey pileKey;
  final int pileCount;
  final String roundStatus;
  final bool isShuffling;
  final double width;
  final double height;
  final VoidCallback onTap;

  const AnimatedPileView({
    super.key,
    required this.pileKey,
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
            // Visual pile indicator
            Container(
              key: pileKey,
              width: 80,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
            ),

            Column(
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
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    "CARDS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A043).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE5A043).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    roundStatus,
                    style: const TextStyle(
                      color: Color(0xFFE5A043),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
