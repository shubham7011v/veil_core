import 'dart:math';
import 'package:flutter/material.dart';

class FloatingEmoji {
  final String id;
  final String emoji;
  final Offset position;

  FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.position,
  });
}

class FloatingEmojiLayer extends StatelessWidget {
  final List<FloatingEmoji> activeEmojis;

  const FloatingEmojiLayer({super.key, required this.activeEmojis});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: activeEmojis
          .map((e) => _FloatingEmojiItem(key: ValueKey(e.id), emoji: e))
          .toList(),
    );
  }
}

class _FloatingEmojiItem extends StatefulWidget {
  final FloatingEmoji emoji;
  const _FloatingEmojiItem({super.key, required this.emoji});

  @override
  State<_FloatingEmojiItem> createState() => _FloatingEmojiItemState();
}

class _FloatingEmojiItemState extends State<_FloatingEmojiItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    final rnd = Random();
    _offset = Tween<Offset>(
      begin: widget.emoji.position,
      end: widget.emoji.position + Offset((rnd.nextDouble() - 0.5) * 60, -200),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

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
        return Positioned(
          left: _offset.value.dx - 20,
          top: _offset.value.dy - 20,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Text(
                widget.emoji.emoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
        );
      },
    );
  }
}
