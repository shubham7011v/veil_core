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
            if (roundStatus.isNotEmpty && roundStatus != "WAITING")
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

            // Visual pile indicator with count
            if (isShuffling)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Color(0xFFE5A043),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "SHUFFLING",
                    style: TextStyle(
                      color: Color(0xFFE5A043),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                key: pileKey,
                width: 90,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Placeholder or Card Backs
                    if (pileCount == 0)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.layers_clear,
                            color: Colors.white24,
                            size: 32,
                          ),
                        ),
                      )
                    else
                      ...List.generate(
                        (pileCount / 2).ceil().clamp(1, 5),
                        (index) => Transform.rotate(
                          angle: (index % 2 == 0 ? 0.05 : -0.05) * index,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C), // Dark card back
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Count Overlay
                    if (pileCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pileCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              "CARDS",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
