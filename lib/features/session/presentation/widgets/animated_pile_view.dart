import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedPileView extends StatefulWidget {
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
  State<AnimatedPileView> createState() => _AnimatedPileViewState();
}

class _AnimatedPileViewState extends State<AnimatedPileView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );
  }

  @override
  void didUpdateWidget(AnimatedPileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pileCount > oldWidget.pileCount) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Physical Card Stack
              if (widget.isShuffling)
                _buildShufflingIndicator()
              else if (widget.pileCount > 0)
                _buildCardStack()
              else
                _buildEmptyPileIndicator(),

              // Round Rank Badge (Floating)
              if (widget.roundStatus.isNotEmpty &&
                  widget.roundStatus != "WAITING")
                Positioned(top: 16, child: _buildRoundRoleBadge()),

              // Pile Key Reference Point for Animations
              if (!widget.isShuffling)
                SizedBox(key: widget.pileKey, width: 1, height: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStack() {
    final int visualCards = min(widget.pileCount, 12);
    final Random random = Random(42);

    return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(visualCards, (index) {
          final double rotation = (random.nextDouble() - 0.5) * 0.4;
          final double offsetX = (random.nextDouble() - 0.5) * 15;
          final double offsetY = (random.nextDouble() - 0.5) * 15;

          return Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: Transform.rotate(
              angle: rotation,
              child: _CardBack(isTopAction: index == visualCards - 1),
            ),
          );
        }),

        // Count Overlay
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.pileCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              Text(
                "CARDS",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoundRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE5A043).withValues(alpha: 0.2),
            const Color(0xFFC48B30).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFE5A043).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5A043).withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.military_tech, color: Color(0xFFE5A043), size: 16),
          const SizedBox(width: 6),
          Text(
            widget.roundStatus,
            style: const TextStyle(
              color: Color(0xFFE5A043),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShufflingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: Color(0xFFE5A043),
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "SHUFFLING",
          style: TextStyle(
            color: const Color(0xFFE5A043).withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPileIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.02),
          ),
          child: Icon(
            Icons.layers_clear,
            color: Colors.white.withValues(alpha: 0.1),
            size: 40,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "PILE EMPTY",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.1),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  final bool isTopAction;

  const _CardBack({this.isTopAction = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 125,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.blur_on,
              color: Colors.white.withValues(alpha: 0.05),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
