import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../session/session.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _playersFound = 1;
  bool _isMatchFound = false;
  bool _isConnecting = false;
  WebSocketSessionHandler? _handler;

  final TextEditingController _urlController = TextEditingController(
    text: 'wss://rebelliously-unforgone-mandie.ngrok-free.dev/ws',
  );
  bool _showDebugInput = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Delay slightly to allow UI to render before starting (or wait for user input)
    Future.delayed(Duration.zero, () {
      if (mounted) _startOnlineMatchmaking();
    });
  }

  Future<void> _startOnlineMatchmaking() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      // 1. Get fresh Firebase token
      final user = FirebaseAuth.instance.currentUser;
      // If bypassed login, use a mock token
      final token = user != null
          ? await user.getIdToken()
          : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

      if (token == null) throw Exception('Failed to get token');

      // 2. Connect
      final handler =
          di.sl.createSessionHandler(online: true) as WebSocketSessionHandler;

      // Use controller text
      await handler.connect(_urlController.text, token);

      _handler = handler; // Store handler for manual start

      // 3. Update SessionBloc
      if (mounted) {
        context.read<SessionBloc>().add(SessionHandlerSwapped(handler));

        handler.sessionStateStream.listen((state) {
          if (state.currentPhase == SessionPhase.thinking && !_isMatchFound) {
            if (mounted) {
              setState(() {
                _isMatchFound = true;
                _playersFound = state.participants.length;
              });
              _onMatchFound();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Show error but stay on screen to allow retry/URL change
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _showDebugInput = true); // Auto-show input on error
      }
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _onMatchFound() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/session');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildAnimatedCards(),
                const Spacer(),
                _buildStatusInfo(),
                if (_playersFound >= 2 && !_isMatchFound) ...[
                  const SizedBox(height: 24),
                  _buildStartNowButton(),
                ],
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F0F), Colors.black],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onLongPress: () =>
                    setState(() => _showDebugInput = !_showDebugInput),
                child: Text(
                  'Finding a Match',
                  style: GoogleFonts.cinzel(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_showDebugInput)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE5A043)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFFE5A043)),
                    onPressed: _startOnlineMatchmaking,
                  ),
                ],
              ),
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

  Widget _buildStartNowButton() {
    return InkWell(
      onTap: () {
        _handler?.startGame();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE5A043),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE5A043).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'START MATCH',
          style: GoogleFonts.cinzel(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
