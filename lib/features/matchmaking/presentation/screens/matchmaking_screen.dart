import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../session/session.dart';
import '../../../auth/auth.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../../core/config/app_config.dart';

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
  StreamSubscription? _statsSubscription;
  StreamSubscription? _sessionStateSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Delay slightly to allow UI to render before starting
    Future.delayed(Duration.zero, () {
      if (mounted) _startOnlineMatchmaking();
    });
  }

  Future<void> _startOnlineMatchmaking() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      // Always use the singleton WebSocket handler
      final handler = di.sl.webSocketSessionHandler;

      debugPrint('Singleton handler status: ${handler.connectionStatus}');

      // Only connect if not already connected
      if (handler.connectionStatus != ConnectionStatus.connected) {
        debugPrint('Not connected, initiating connection...');
        final user = FirebaseAuth.instance.currentUser;
        final token = user != null
            ? await user.getIdToken()
            : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

        if (token == null) throw Exception('Failed to get token');

        await handler.connect(
          AppConfig.instance.serverUrl,
          token,
          displayName: user?.displayName,
        );

        // Wait for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint('Already connected, reusing connection');
      }

      // Update SessionBloc with the handler
      if (mounted) {
        context.read<SessionBloc>().add(SessionHandlerSwapped(handler));
      }

      _handler = handler;

      // Set up listeners (only if not already listening)
      if (mounted) {
        _statsSubscription = handler.statsStream.listen((stats) {
          if (mounted) {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              context.read<AuthBloc>().add(AuthStatsUpdated(stats));
            }
          }
        });

        _sessionStateSubscription = handler.sessionStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _playersFound = state.participants.length;
            });
          }

          if (state.currentPhase == SessionPhase.thinking && !_isMatchFound) {
            if (mounted) {
              setState(() {
                _isMatchFound = true;
              });
              _onMatchFound();
            }
          }
        });

        // Wait for connection to be fully established before joining matchmaking
        await Future.delayed(const Duration(milliseconds: 500));

        // NOW send JOIN_ROOM to enter matchmaking queue
        if (mounted && handler.connectionStatus == ConnectionStatus.connected) {
          handler.joinMatchmaking();
          debugPrint('Joined matchmaking queue');
        } else {
          debugPrint('Connection not ready, waiting for reconnection...');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _onMatchFound() {
    Future.delayed(
      Duration(seconds: AppConfig.instance.matchmakingDelaySeconds),
      () {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/session',
            arguments: {'useWebSocket': true},
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _statsSubscription?.cancel();
    _sessionStateSubscription?.cancel();
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
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final int userCoins = state is Authenticated
            ? (state.stats?.coins ?? 0)
            : 0;
        final bool canAfford = userCoins >= 100;

        return Column(
          children: [
            Text(
              'Entry Fee: 100 Coins',
              style: GoogleFonts.inter(
                color: canAfford ? Colors.white54 : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: canAfford
                  ? () {
                      _handler?.startGame();
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: canAfford
                      ? const Color(0xFFE5A043)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: canAfford
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFE5A043,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  canAfford ? 'START MATCH' : 'INSUFFICIENT COINS',
                  style: GoogleFonts.cinzel(
                    color: canAfford ? Colors.black : Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
