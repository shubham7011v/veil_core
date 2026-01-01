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
    // For this app, assuming we show faces in "Hand" (which is where this is used mostly)
    // If it's the player's hand, they see the face.
    // The design shows a cream/off-white unit face.
    const Color cardFaceColor = Color(0xFFFDFCF5);

    final String rankLabel = _getRankLabel(unit.rank);
    final bool isMultiChar = rankLabel.length > 1;

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rotation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: cardFaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(
                        0xFFFFD700,
                      ).withValues(alpha: 0.6), // Gold glow
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, -4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: Stack(
            children: [
              // Top Left Rank & Suit
              Positioned(
                top: 6,
                left: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rankLabel,
                      style: TextStyle(
                        color: _getSuitColor(unit.type),
                        fontWeight: FontWeight.w900,
                        fontSize: isMultiChar ? 13 : 16,
                        fontFamily: 'Serif',
                        height: 1.0,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Icon(
                      _getSuitIcon(unit.type),
                      size: 13,
                      color: _getSuitColor(unit.type),
                    ),
                  ],
                ),
              ),

              // Center Large Suit Watermark
              Center(
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(
                    _getSuitIcon(unit.type),
                    size: width * 0.6,
                    color: _getSuitColor(unit.type),
                  ),
                ),
              ),

              // Bottom Right Rank (Inverted)
              Positioned(
                bottom: 8,
                right: 8,
                child: Transform.rotate(
                  angle: 3.14159, // 180 degrees
                  child: Text(
                    _getRankLabel(unit.rank),
                    style: TextStyle(
                      color: _getSuitColor(unit.type),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      fontFamily: 'Serif',
                      height: 1.0,
                    ),
                  ),
                ),
              ),

              // Selection Checkmark Badge
              if (isSelected)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700), // Gold
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRankLabel(UnitRank rank) {
    if (rank == UnitRank.joker) return 'JK';
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
      default:
        return Colors.black;
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
      case UnitType.joker:
        return Icons.theater_comedy;
    }
  }
}
