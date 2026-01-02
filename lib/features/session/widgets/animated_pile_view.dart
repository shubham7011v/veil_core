import 'package:flutter/material.dart';
import 'dart:math' as dart_math;

class AnimatedPileView extends StatefulWidget {
  final int pileCount;
  final String roundStatus;
  final VoidCallback onTap;
  final GlobalKey? pileKey;

  const AnimatedPileView({
    super.key,
    required this.pileCount,
    required this.roundStatus,
    required this.onTap,
    this.pileKey,
  });

  @override
  State<AnimatedPileView> createState() => _AnimatedPileViewState();
}

class _AnimatedPileViewState extends State<AnimatedPileView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressureController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pressureAnimation;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.pileCount;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _pressureController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pressureAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_pressureController);
    _pressureController.repeat();
    _updatePressureSpeed();
  }

  void _updatePressureSpeed() {
    final speedMultiplier = 1.0 + (widget.pileCount / 10).clamp(0.0, 4.0);
    _pressureController.duration = Duration(
      milliseconds: (2000 / speedMultiplier).toInt(),
    );
    _pressureController.repeat();
  }

  @override
  void didUpdateWidget(AnimatedPileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pileCount > _prevCount) {
      _controller.forward(from: 0.0);
      _updatePressureSpeed();
    }
    _prevCount = widget.pileCount;
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressureColor = Color.lerp(
      const Color(0xFFFFD700),
      const Color(0xFFD32F2F),
      (widget.pileCount / 30).clamp(0.0, 1.0),
    )!;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        key: widget.pileKey,
        alignment: Alignment.center,
        children: [
          if (widget.pileCount > 0)
            AnimatedBuilder(
              animation: _pressureAnimation,
              builder: (context, child) {
                return Container(
                  width: 190 + (20 * _pressureAnimation.value),
                  height: 190 + (20 * _pressureAnimation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pressureColor.withValues(
                        alpha: 0.3 * (1 - _pressureAnimation.value),
                      ),
                      width: 4,
                    ),
                  ),
                );
              },
            ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.pileCount > 0
                          ? pressureColor
                          : Colors.white24,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: pressureColor.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.style,
                        size: 60,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
                if (widget.pileCount > 1)
                  ...List.generate(
                    dart_math.min(widget.pileCount, 5),
                    (i) => Positioned(
                      top: i * 2.0,
                      left: i * 2.0,
                      child: Container(
                        width: 140,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10, width: 1),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 20,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFECB3),
                        Color(0xFFB8860B),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      widget.roundStatus.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  right: 15,
                  child: Text(
                    'PILE',
                    style: TextStyle(
                      color: pressureColor.withValues(alpha: 0.5),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pressureColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '${widget.pileCount}',
                        key: ValueKey(widget.pileCount),
                        style: TextStyle(
                          color: pressureColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParticleExplosionOverlay extends StatefulWidget {
  final Color color;
  const ParticleExplosionOverlay({super.key, required this.color});

  @override
  State<ParticleExplosionOverlay> createState() =>
      _ParticleExplosionOverlayState();
}

class _ParticleExplosionOverlayState extends State<ParticleExplosionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle());
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final progress = _controller.value;
            final double x =
                (MediaQuery.of(context).size.width / 2) +
                (p.dx * progress * 300);
            final double y =
                (MediaQuery.of(context).size.height / 2) -
                50 +
                (p.dy * progress * 300) +
                (progress * progress * 150);

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: (1.0 - progress).clamp(0.0, 1.0),
                child: Container(
                  width: 6 + (1 - progress) * 4,
                  height: 6 + (1 - progress) * 4,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  late double dx;
  late double dy;
  _Particle() {
    final rnd = dart_math.Random();
    final angle = rnd.nextDouble() * 2 * dart_math.pi;
    final speed = 0.3 + rnd.nextDouble() * 0.7;
    dx = dart_math.cos(angle) * speed;
    dy = dart_math.sin(angle) * speed;
  }
}
