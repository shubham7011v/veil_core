import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';

class CardFlipView extends StatelessWidget {
  final bool isFlipped;
  final Widget front;
  final Widget back;

  const CardFlipView({
    super.key,
    required this.isFlipped,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    AppLogger.info("CardFlipView build: isFlipped=$isFlipped");
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final rotate = Tween(begin: pi, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotate,
          builder: (BuildContext context, Widget? child) {
            final isUnder = (ValueKey(isFlipped) != child?.key);
            var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
            tilt *= isUnder ? -1.0 : 1.0;
            final value = isUnder ? min(rotate.value, pi / 2) : rotate.value;
            return Transform(
              transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: child,
        );
      },
      child: isFlipped
          ? SizedBox(key: const ValueKey(true), child: back)
          : SizedBox(key: const ValueKey(false), child: front),
    );
  }
}
