import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IntroMoodPage extends StatefulWidget {
  const IntroMoodPage({super.key});

  @override
  State<IntroMoodPage> createState() => _IntroMoodPageState();
}

class _IntroMoodPageState extends State<IntroMoodPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showTitle = false;
  bool _showSubtitle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Sequence animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showTitle = true);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showSubtitle = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Particles (Simulating Lottie)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    progress: _controller.value,
                    color: const Color(0xFFE5A043).withValues(alpha: 0.05),
                  ),
                );
              },
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _showTitle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    'BLUFF',
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFE5A043),
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: _showSubtitle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    'Where lies rule\nand truth burns',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 18,
                      height: 1.5,
                      letterSpacing: 1.2,
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

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<math.Point> _points = List.generate(
    20,
    (index) => math.Point(
      math.Random(index).nextDouble(),
      math.Random(index + 100).nextDouble(),
    ),
  );

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      // Slow float upwards
      double x = p.x * size.width;
      double y = ((p.y - progress) % 1.0) * size.height;

      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
