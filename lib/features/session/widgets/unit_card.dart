import 'package:flutter/material.dart';
import '../../../core/constants/dimens.dart';
import '../models/unit.dart';

class UnitCard extends StatelessWidget {
  final Unit unit;
  final VoidCallback onTap;
  final bool isSelected;
  final double width;
  final double height;
  final double rotation;

  const UnitCard({
    super.key,
    required this.unit,
    required this.onTap,
    this.isSelected = false,
    this.width = AppDimens.cardWidth,
    this.height = AppDimens.cardHeight,
    this.rotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardFaceColor = Color(0xFFFAF9F6); // Premium Ivory
    final String rankLabel = _getRankLabel(unit.rank);
    final bool isMultiChar = rankLabel.length > 1;
    final Color suitColor = _getSuitColor(unit.type);

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: isSelected ? -15.0 : 0.0),
        builder: (context, translateY, child) {
          return Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.rotate(
              angle: rotation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: cardFaceColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    // Base Shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: isSelected ? 12 : 6,
                      offset: Offset(0, isSelected ? 10 : 4),
                    ),
                    // Gold Glow if selected
                    if (isSelected)
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                  ],
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFD700)
                        : Colors.black12,
                    width: isSelected ? 2 : 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Glossy Overlay (Linear gradient for lighting)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Top Left Rank & Suit
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rankLabel,
                              style: TextStyle(
                                color: suitColor,
                                fontWeight: FontWeight.bold,
                                fontSize: isMultiChar ? 13 : 16,
                                height: 1.0,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Icon(
                              _getSuitIcon(unit.type),
                              size: 11,
                              color: suitColor,
                            ),
                          ],
                        ),
                      ),

                      // Center Large Suit Watermark
                      Center(
                        child: Opacity(
                          opacity: 0.08,
                          child: Icon(
                            _getSuitIcon(unit.type),
                            size: width * 0.5,
                            color: suitColor,
                          ),
                        ),
                      ),

                      // Bottom Right Rank (Inverted)
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Transform.rotate(
                          angle: 3.14159,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                rankLabel,
                                style: TextStyle(
                                  color: suitColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMultiChar ? 13 : 16,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Premium Glossy Highlight (Curved light)
                      Positioned(
                        top: -height * 0.4,
                        left: -width * 0.5,
                        child: Opacity(
                          opacity: 0.15,
                          child: Container(
                            width: width * 1.5,
                            height: height * 0.8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                      // Selection Checkmark Overlay
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getRankLabel(UnitRank rank) {
    if (rank.index <= UnitRank.ten.index && rank.index >= UnitRank.two.index) {
      return (rank.index + 2).toString();
    }
    return rank.name[0].toUpperCase();
  }

  Color _getSuitColor(UnitType type) {
    switch (type) {
      case UnitType.hearts:
      case UnitType.diamonds:
        return const Color(0xFFD32F2F); // Crimson Red
      case UnitType.spades:
      case UnitType.clubs:
        return const Color(0xFF212121); // Almost Black
    }
  }

  IconData _getSuitIcon(UnitType type) {
    switch (type) {
      case UnitType.spades:
        return Icons
            .spoke; // Material doesn't have perfect suit icons, using approximations or standard
      case UnitType.hearts:
        return Icons.favorite;
      case UnitType.diamonds:
        return Icons.diamond;
      case UnitType.clubs:
        return Icons.local_florist; // Approximation
    }
  }
}
