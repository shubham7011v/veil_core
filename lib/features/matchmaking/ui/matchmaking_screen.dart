import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../session/bloc/session_bloc.dart';
import '../../session/bloc/session_event.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _playersFound = 1;
  Timer? _timer;
  bool _isMatchFound = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _startMatchmakingSimulation();
  }

  void _startMatchmakingSimulation() {
    // 20% chance for an "instant match" skip
    if (math.Random().nextDouble() < 0.2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SessionBloc>().add(
            const SessionStartRequested(playerCount: 4),
          );
          Navigator.pushReplacementNamed(context, '/session');
        }
      });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _playersFound < 4) {
        setState(() {
          _playersFound++;
          if (_playersFound == 4) {
            _isMatchFound = true;
            _onMatchFound();
          }
        });
      }

      // Speed up animation if taking long (10s+)
      if (timer.tick == 5) {
        setState(() {
          _controller.duration = const Duration(seconds: 1);
          if (_controller.isAnimating) {
            _controller.repeat();
          }
        });
      }
    });
  }

  void _onMatchFound() {
    _timer?.cancel();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        context.read<SessionBloc>().add(
          const SessionStartRequested(playerCount: 4),
        );
        Navigator.pushReplacementNamed(context, '/session');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Backdrop with Vignette
          _buildBackground(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildAnimatedCards(),
                const Spacer(),
                _buildStatusInfo(),
                const SizedBox(height: 48),
                _buildCancelButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Colors.grey[900]!.withValues(alpha: 0.2), Colors.black],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Finding a Match',
            style: GoogleFonts.cinzel(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo() {
    return Column(
      children: [
        Text(
          _isMatchFound ? 'Match Found!' : 'Looking for players...',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Players found: $_playersFound / 4',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFE5A043),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCards() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(4, (index) {
            final double offset = (index * 2 * math.pi / 4);
            final double angle = _controller.value * 2 * math.pi + offset;
            final double radius = 60.0;

            return Transform.translate(
              offset: Offset(
                math.cos(angle) * radius,
                math.sin(angle) * radius * 0.3, // Slight oval
              ),
              child: Transform.rotate(
                angle: angle + math.pi / 2,
                child: _buildFacingDownCard(),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildFacingDownCard() {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.style,
            color: Colors.white.withValues(alpha: 0.05),
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        'Cancel',
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
