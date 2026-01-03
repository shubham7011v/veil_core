import 'dart:math';
import 'package:flutter/material.dart';

class FlyingCard {
  final String id;
  final Offset start;
  final Offset end;
  final int count;

  FlyingCard({
    required this.id,
    required this.start,
    required this.end,
    this.count = 1,
  });
}

class FlyingCardsLayer extends StatelessWidget {
  final List<FlyingCard> activeAnimations;

  const FlyingCardsLayer({super.key, required this.activeAnimations});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: activeAnimations
          .map((anim) => _FlyingCardItem(anim: anim))
          .toList(),
    );
  }
}

class _FlyingCardItem extends StatefulWidget {
  final FlyingCard anim;
  const _FlyingCardItem({required this.anim});

  @override
  State<_FlyingCardItem> createState() => _FlyingCardItemState();
}

class _FlyingCardItemState extends State<_FlyingCardItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _posAnim;
  late Animation<double> _rotAnim;
  late Animation<double> _scaleAnim;
  late List<double> _offsets;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _posAnim = Tween<Offset>(begin: widget.anim.start, end: widget.anim.end)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );

    _rotAnim = Tween<double>(
      begin: 0,
      end: (Random().nextDouble() - 0.5) * 4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.8), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _offsets = List.generate(widget.anim.count, (index) => index.toDouble());

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
          children: _offsets.map((idx) {
            // Apply a slight spread for multiple cards
            final double spreadX =
                (idx - (_offsets.length / 2)) * 10 * _controller.value;
            final double spreadY =
                (idx - (_offsets.length / 2)) * 5 * _controller.value;

            return Positioned(
              left: _posAnim.value.dx - 25 + spreadX,
              top: _posAnim.value.dy - 35 + spreadY,
              child: Transform.rotate(
                angle: _rotAnim.value + (idx * 0.1),
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: 50,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10 * _controller.value,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.white12,
                        size: 20,
                      ),
                    ),
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
