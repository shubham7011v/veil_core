import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/navigation/fade_route.dart';
import '../../../../core/utils/app_logger.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'intro_screen.dart';
import '../../../../core/di/service_locator.dart' as di;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Wait for the splash duration (500-700ms)
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    final authBloc = context.read<AuthBloc>();
    final onboardingRepo = di.sl.onboardingRepository;

    // 1. If currently Unauthenticated or AuthInitial, attempt silent sign-in
    AppLogger.info('🔍 [SplashScreen] Initial State: ${authBloc.state}');
    if (authBloc.state is Unauthenticated || authBloc.state is AuthInitial) {
      AppLogger.info('🔍 [SplashScreen] Attempting Silent Sign-in...');
      authBloc.add(AuthSilentSignInRequested());

      // Wait for AuthBloc to resolve (timeout after 2s for safety)
      try {
        await authBloc.stream
            .firstWhere((state) {
              AppLogger.info('🔍 [SplashScreen] Stream State Update: $state');
              return state is! AuthLoading && state is! AuthInitial;
            })
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        // Log or handle timeout
        AppLogger.error('Silent sign-in timed out or failed', exception: e);
      }
    }

    if (!mounted) return;

    // Remove native splash just before transitioning
    FlutterNativeSplash.remove();

    final state = authBloc.state;
    AppLogger.info('🔍 [SplashScreen] Final State Decision: $state');

    if (state is Authenticated) {
      Navigator.of(context).pushReplacementNamed('/court_entry');
    } else {
      final hasSeenIntro = onboardingRepo.hasSeenIntro();
      if (!hasSeenIntro) {
        Navigator.of(
          context,
        ).pushReplacement(FadeRoute(page: const IntroScreen(initialPage: 0)));
      } else {
        // Go straight to sign-in page (last page of IntroScreen)
        Navigator.of(
          context,
        ).pushReplacement(FadeRoute(page: const IntroScreen(initialPage: 2)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE5A043).withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.security, // Shield-like icon
                  size: 80,
                  color: Color(0xFFE5A043),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
