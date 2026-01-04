import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/di/service_locator.dart' as di;

class IntroEntryPage extends StatefulWidget {
  const IntroEntryPage({super.key});

  @override
  State<IntroEntryPage> createState() => _IntroEntryPageState();
}

class _IntroEntryPageState extends State<IntroEntryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          di.sl.onboardingRepository.markIntroAsSeen();
          Navigator.of(context).pushReplacementNamed('/court_entry');
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background Silhouette Placeholder (Very subtle)
            Positioned.fill(
              child: Opacity(
                opacity: 0.03, // 2-3%
                child: CustomPaint(painter: _SilhouettePainter()),
              ),
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onLongPress: () {
                      // Bypass to home for testing
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/court_entry');
                    },
                    child: Text(
                      'Play with real players.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFE5A043),
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Outsmart everyone.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFE5A043),
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 80),
                  AnimatedOpacity(
                    opacity: _showButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 1000),
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.02).animate(
                            CurvedAnimation(
                              parent: _pulseController,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: OutlinedButton(
                            onPressed: () => context.read<AuthBloc>().add(
                              GoogleSignInRequested(),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE5A043),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.login,
                                  color: Color(0xFFE5A043),
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  state is AuthLoading
                                      ? 'ASCENDING...'
                                      : 'ENTER THE COURT',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    // Simulate a table and silhouettes at the bottom
    path.moveTo(0, size.height * 0.85);
    path.lineTo(size.width * 0.2, size.height * 0.75);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.72);
    path.lineTo(size.width * 0.8, size.height * 0.78);
    path.lineTo(size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
