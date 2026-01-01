import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(0, isSelected ? -20 : 0),
        child: Transform.rotate(
          angle: rotation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors
                  .cardBack, // Or face color if revealed (not needed for Ph 1 usually)
              borderRadius: BorderRadius.circular(AppDimens.radiusS),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.activeGlow.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Corner Rank/Suit
                Positioned(
                  top: 4,
                  left: 6,
                  child: Column(
                    children: [
                      Text(
                        _getRankLabel(unit.rank),
                        style: TextStyle(
                          color: _getSuitColor(unit.type),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        _getSuitIcon(unit.type),
                        size: 12,
                        color: _getSuitColor(unit.type),
                      ),
                    ],
                  ),
                ),
                // Center Icon (Simplified)
                Center(
                  child: Icon(
                    _getSuitIcon(unit.type),
                    size: 24,
                    color: _getSuitColor(unit.type).withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRankLabel(UnitRank rank) {
    if (rank == UnitRank.joker) return 'J';
    if (rank.index <= UnitRank.ten.index && rank.index >= UnitRank.two.index) {
      return (rank.index + 2).toString();
    }
    return rank.name[0].toUpperCase();
  }

  Color _getSuitColor(UnitType type) {
    switch (type) {
      case UnitType.hearts:
      case UnitType.diamonds:
        return AppColors.danger; // Use danger/red color
      case UnitType.spades:
      case UnitType.clubs:
        return AppColors.textPrimary;
      default:
        return AppColors.primary;
    }
  }

  IconData _getSuitIcon(UnitType type) {
    switch (type) {
      case UnitType.spades:
        return Icons.eco; // Placeholder for Spade
      case UnitType.hearts:
        return Icons.favorite;
      case UnitType.diamonds:
        return Icons.diamond;
      case UnitType.clubs:
        return Icons.yard; // Placeholder for Club
      case UnitType.joker:
        return Icons.sentiment_very_satisfied;
    }
  }
}
