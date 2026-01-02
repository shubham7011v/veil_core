import 'package:flutter/material.dart';
import 'dart:math' as math;

class FlyingCard {
  final Offset start;
  final Offset end;
  final int count;
  final DateTime startTime;

  FlyingCard({required this.start, required this.end, required this.count})
    : startTime = DateTime.now();
}

class FlyingCardsLayer extends StatefulWidget {
  final List<FlyingCard> activeAnimations;
  final VoidCallback onComplete;

  const FlyingCardsLayer({
    super.key,
    required this.activeAnimations,
    required this.onComplete,
  });

  @override
  State<FlyingCardsLayer> createState() => _FlyingCardsLayerState();
}

class _FlyingCardsLayerState extends State<FlyingCardsLayer>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    if (widget.activeAnimations.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: widget.activeAnimations.map((anim) {
        return _FlyingCardAnimation(
          anim: anim,
          onComplete: () {
            // We'll let the parent handle removal
          },
        );
      }).toList(),
    );
  }
}

class _FlyingCardAnimation extends StatefulWidget {
  final FlyingCard anim;
  final VoidCallback onComplete;

  const _FlyingCardAnimation({required this.anim, required this.onComplete});

  @override
  State<_FlyingCardAnimation> createState() => _FlyingCardAnimationState();
}

class _FlyingCardAnimationState extends State<_FlyingCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        // Curved path: Quadratic Bezier
        // Control point: move slightly to the side
        final cp = Offset(
          (widget.anim.start.dx + widget.anim.end.dx) / 2 + 50,
          (widget.anim.start.dy + widget.anim.end.dy) / 2 - 100,
        );

        // B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
        final x =
            math.pow(1 - t, 2) * widget.anim.start.dx +
            2 * (1 - t) * t * cp.dx +
            math.pow(t, 2) * widget.anim.end.dx;
        final y =
            math.pow(1 - t, 2) * widget.anim.start.dy +
            2 * (1 - t) * t * cp.dy +
            math.pow(t, 2) * widget.anim.end.dy;

        final rotation = t * math.pi * 2;
        final scale = 1.0 - (t * 0.3); // Shrink slightly as it reaches the pile

        return Positioned(
          left: x - 25,
          top: y - 35,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: _buildCardStack(widget.anim.count),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStack(int count) {
    return SizedBox(
      width: 74, // Increased width for larger offset
      height: 94, // Increased height for larger offset
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(
          math.min(count, 4),
          (i) => Positioned(
            top: i * 6.0,
            left: i * 6.0,
            child: Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white38, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.style, color: Colors.white10, size: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
