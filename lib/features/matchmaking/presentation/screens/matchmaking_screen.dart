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
  bool _isStartingMatch = false; // Add spam protection flag
  WebSocketSessionHandler? _handler;
  StreamSubscription? _statsSubscription;
  StreamSubscription? _sessionStateSubscription;
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _errorSubscription; // New error listener
  List<Participant> _participants = [];
  int _countdown = 10;
  Timer? _countdownTimer;
  Timer? _timeoutTimer; // New timeout timer
  Timer? _waitTimer; // Timer for the total wait duration
  final Stopwatch _stopwatch = Stopwatch(); // Track total wait time
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
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
      final handler = di.sl.webSocketSessionHandler;

      // Update local status immediately
      setState(() => _connectionStatus = handler.connectionStatus);

      if (handler.connectionStatus != ConnectionStatus.connected) {
        final user = FirebaseAuth.instance.currentUser;
        final token = user != null
            ? await user.getIdToken()
            : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

        await handler.connect(
          AppConfig.instance.serverUrl,
          token!,
          displayName: user?.displayName,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      handler.resetGameSession();
      if (mounted) {
        context.read<SessionBloc>().add(SessionHandlerSwapped(handler));
      }

      _handler = handler;

      if (mounted) {
        // Stats Listener
        _statsSubscription = handler.statsStream.listen((stats) {
          if (mounted) {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              context.read<AuthBloc>().add(AuthStatsUpdated(stats));
            }
          }
        });

        // Error Listener (NEW)
        _errorSubscription = handler.errorStream.listen((failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${failure.message}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );

            // If critical error (like auth fail or funds), maybe pop?
            if (failure.message.contains('Funds')) {
              Navigator.pop(context);
            }
          }
        });

        // Connection Status Listener (NEW)
        _connectionStatusSubscription = handler.connectionStatusStream.listen((
          status,
        ) {
          if (mounted) {
            setState(() => _connectionStatus = status);

            if (status == ConnectionStatus.connected && !_isMatchFound) {
              // Auto-rejoin if we were disconnected
              handler.joinMatchmaking();
            }
          }
        });

        // Session State Listener
        _sessionStateSubscription = handler.sessionStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _playersFound = state.participants.length;
              _participants = state.participants;
            });

            if (state.startTime != null) {
              _syncCountdown(state.startTime!);
            } else {
              if (_countdownTimer != null) {
                _countdownTimer!.cancel();
                _countdownTimer = null;
                setState(() => _countdown = 0);
              }
            }
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

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted && handler.connectionStatus == ConnectionStatus.connected) {
          handler.joinMatchmaking();
          _startTimeoutTimer(); // Start the "taking too long" timer
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && !_isMatchFound) {
        _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Taking a while...',
          style: GoogleFonts.cinzel(color: Colors.white),
        ),
        content: Text(
          'Matchmaking is taking longer than usual. Do you want to keep waiting?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Leave screen
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimeoutTimer(); // Restart timer
            },
            child: const Text(
              'Wait',
              style: TextStyle(color: Color(0xFFE5A043)),
            ),
          ),
        ],
      ),
    );
  }

  void _syncCountdown(int startTimeUnix) {
    if (_countdownTimer != null && _countdownTimer!.isActive) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final remaining = startTimeUnix - now;

        if (remaining <= 0) {
          timer.cancel();
          setState(() {
            _countdown = 0;
          });
        } else {
          setState(() {
            _countdown = remaining;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _onMatchFound() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
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
    _stopwatch.stop();
    _waitTimer?.cancel();
    _handler?.leaveRoom('');
    _controller.dispose();
    _statsSubscription?.cancel();
    _sessionStateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _countdownTimer?.cancel();
    _timeoutTimer?.cancel();
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
                if (_connectionStatus != ConnectionStatus.connected)
                  _buildConnectionBanner(), // New Banner
                const SizedBox(height: 24),
                _buildStatusInfo(),
                const SizedBox(height: 32),
                SizedBox(height: 140, child: _buildAnimatedCards()),
                const SizedBox(height: 32),
                Expanded(child: _buildParticipantsList()),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final isReconnecting =
        _connectionStatus == ConnectionStatus.reconnecting ||
        _connectionStatus == ConnectionStatus.connecting;
    return Container(
      width: double.infinity,
      color: isReconnecting ? Colors.orangeAccent : Colors.redAccent,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          isReconnecting ? 'Reconnecting to server...' : 'Connection Lost',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
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
    final elapsed = _stopwatch.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 4),
                  Text(
                    'Time Elapsed: $minutes:$seconds',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
          'Players found: $_playersFound / 5',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFE5A043),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_countdownTimer != null && _countdown > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Starting in $_countdown seconds...',
            style: GoogleFonts.inter(
              color: Colors.greenAccent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParticipantsList() {
    const int maxPlayers = 5;
    final List<Widget> slots = [];

    // Sort participants to show 'me' first if available
    final List<Participant> sortedParticipants = List.from(_participants);
    sortedParticipants.sort((a, b) {
      if (a.isMe) return -1;
      if (b.isMe) return 1;
      return 0;
    });

    // Add actual participants
    for (int i = 0; i < sortedParticipants.length; i++) {
      slots.add(
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: _buildParticipantCard(sortedParticipants[i]),
        ),
      );
    }

    // Add empty slots for remaining spots
    final remainingSlots = maxPlayers - sortedParticipants.length;
    for (int i = 0; i < remainingSlots; i++) {
      slots.add(_buildEmptySlot(sortedParticipants.length + i + 1));
    }

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      childAspectRatio: 0.75,
      children: slots,
    );
  }

  Widget _buildParticipantCard(Participant participant) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: participant.isMe ? const Color(0xFFE5A043) : Colors.white10,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2C2C2C),
              image:
                  (participant.avatarUrl != null &&
                      participant.avatarUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(participant.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(
                color: participant.isMe
                    ? const Color(0xFFE5A043)
                    : const Color(0xFF4CAF50),
                width: 2,
              ),
            ),
            child:
                (participant.avatarUrl == null ||
                    participant.avatarUrl!.isEmpty)
                ? Center(
                    child: Text(
                      participant.name.isNotEmpty
                          ? participant.name[0].toUpperCase()
                          : 'P',
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            participant.isMe ? 'Me' : participant.name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (participant.rank != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participant.rank!.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5A043),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          const SizedBox(height: 4),
          if (!participant.isMe)
            Text(
              'Ready',
              style: GoogleFonts.inter(
                color: const Color(0xFF4CAF50),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(int slotNumber) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 2),
            ),
            child: Icon(
              Icons.person_outline,
              color: Colors.white.withValues(alpha: 0.2),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting...',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
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
              onTap: (canAfford && !_isStartingMatch)
                  ? () {
                      setState(() => _isStartingMatch = true);
                      _handler?.startGame();
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: (canAfford && !_isStartingMatch)
                      ? const Color(0xFFE5A043)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: (canAfford && !_isStartingMatch)
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
                  !canAfford
                      ? 'INSUFFICIENT COINS'
                      : (_isStartingMatch ? 'STARTING...' : 'START MATCH'),
                  style: GoogleFonts.cinzel(
                    color: (canAfford && !_isStartingMatch)
                        ? Colors.black
                        : Colors.white38,
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
