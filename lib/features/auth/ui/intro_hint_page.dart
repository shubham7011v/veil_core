import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IntroHintPage extends StatefulWidget {
  const IntroHintPage({super.key});

  @override
  State<IntroHintPage> createState() => _IntroHintPageState();
}

class _IntroHintPageState extends State<IntroHintPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF000000),
                  Color(0xFF1A1A1A), // Deep charcoal
                ],
              ),
            ),
          ),

          // Sliding Cards (Subtle Background)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  _buildSlidingCard(-0.2, 0.3, 0.8), // Card 1
                  _buildSlidingCard(0.5, 0.7, 1.2), // Card 2
                  _buildSlidingCard(0.1, 0.1, 0.5), // Card 3
                ],
              );
            },
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lie with confidence.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFE5A043),
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Call bluffs\nat the right moment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFE5A043),
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingCard(double startX, double y, double speedFactor) {
    double progress = (_controller.value * speedFactor + startX) % 1.2;
    // Map progress to screen width with some overflow
    double xPos = (progress - 0.2) * MediaQuery.of(context).size.width * 1.2;

    return Positioned(
      left: xPos,
      top: MediaQuery.of(context).size.height * y,
      child: Opacity(
        opacity: 0.04, // 3-4% opacity
        child: Container(
          width: 140,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFE5A043),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Center(
            child: Icon(Icons.shield, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}
