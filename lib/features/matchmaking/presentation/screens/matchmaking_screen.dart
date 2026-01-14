import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../session/session.dart';
import '../../../auth/auth.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../../core/engine/domain/models/room_event.dart'; // NEW
import '../../../../core/config/app_config.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  int _playersFound = 1;
  bool _isMatchFound = false;
  bool _isConnecting = false;
  WebSocketSessionHandler? _handler;
  StreamSubscription? _statsSubscription;
  StreamSubscription? _sessionStateSubscription;
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _roomEventSubscription;
  List<Participant> _participants = [];
  Timer? _countdownTimer;
  Timer? _timeoutTimer;
  Timer? _waitTimer; // Restore this
  int _lobbyCreatedAt = 0; // Unix timestamp for lobby start
  int _secondsRemaining = 60; // Default count

  bool _hasShownTimeoutDialog = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  bool _isManualPop = false; // Track if user manually pressed back

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

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

        // Connect with retry
        int retries = 0;
        while (retries < 3) {
          try {
            await handler.connect(
              AppConfig.instance.serverUrl,
              token!,
              displayName: user?.displayName,
            );
            if (handler.connectionStatus == ConnectionStatus.connected) break;
          } catch (e) {
            debugPrint('Connect attempt ${retries + 1} failed: $e');
            retries++;
            if (retries >= 3) rethrow;
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      handler.resetGameSession();
      if (mounted) {
        context.read<SessionBloc>().add(SessionHandlerSwapped(handler));
      } else {
        return; // Exit if unmounted after async
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
            final prevCount = _playersFound;
            setState(() {
              _playersFound = state.participants.length;
              _participants = state.participants;
              if (state.createdAt != null &&
                  _lobbyCreatedAt != state.createdAt) {
                _lobbyCreatedAt = state.createdAt!;
                _hasShownTimeoutDialog = false;
                _syncLobbyTimer();
              }
            });

            if (_playersFound > prevCount) {
              HapticFeedback.mediumImpact();
            }

            if (state.startTime == null) {
              if (_countdownTimer != null) {
                _countdownTimer!.cancel();
                _countdownTimer = null;
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

        // Room Event Listener (for createdAt sync)
        _roomEventSubscription = handler.roomEventStream.listen((evt) {
          if (!mounted) return;

          int? newCreatedAt;
          if (evt is RoomCreated) {
            newCreatedAt = evt.createdAt;
          } else if (evt is RoomJoined) {
            newCreatedAt = evt.createdAt;
          } else if (evt is RoomUpdated) {
            newCreatedAt = evt.createdAt;

            // Sync participants from RoomUpdated event
            if (evt.participants.isNotEmpty) {
              final prevCount = _playersFound;
              setState(() {
                _participants = evt.participants;
                _playersFound = evt.participants.length;
              });
              if (_playersFound > prevCount) {
                HapticFeedback.mediumImpact();
              }
            }
          }

          if (newCreatedAt != null) {
            // Normalize: If it's in milliseconds (> 2000000000), convert to seconds
            // Threshold: 2 billion (Year 2033) is safe for current epoch seconds
            final normalized = newCreatedAt > 2000000000
                ? newCreatedAt ~/ 1000
                : newCreatedAt;

            if (_lobbyCreatedAt != normalized) {
              setState(() {
                _lobbyCreatedAt = normalized;
                _hasShownTimeoutDialog = false;
                _syncLobbyTimer();
              });
            }
          }

          // Optimistically add "Me" if list is empty upon joining
          if ((evt is RoomJoined || evt is RoomCreated) &&
              _participants.isEmpty) {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              final me = Participant(
                id: authState.user.uid,
                name: authState.user.displayName ?? 'Me',
                avatarUrl: authState.user.photoURL,
                unitCount: 5, // Default start count
                isMe: true,
                isActive: true,
              );
              setState(() {
                _participants = [me];
                _playersFound = 1;
              });
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

  void _syncLobbyTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final elapsed = now - _lobbyCreatedAt;
      int remaining = 60 - elapsed;
      if (remaining < 0) remaining = 0;

      setState(() {
        _secondsRemaining = remaining;
      });

      // Show Popup at 15 seconds remaining
      if (remaining <= 15 && !_hasShownTimeoutDialog) {
        _hasShownTimeoutDialog = true;
        _showTimeoutDialog();
      }

      // Haptic countdown for last 5 seconds
      if (remaining <= 5 && remaining > 0) {
        HapticFeedback.selectionClick();
      }

      if (remaining <= 0) {
        HapticFeedback.heavyImpact(); // Final trigger
        timer.cancel();
      }
    });
  }

  void _showTimeoutDialog() {
    if (!mounted) return;

    Timer? autoDismissTimer;
    bool isDialogActive = true;

    // Auto-dismiss after 5 seconds
    autoDismissTimer = Timer(const Duration(seconds: 5), () {
      if (isDialogActive && mounted) {
        Navigator.of(context).pop();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(
          '15 Seconds Remaining!',
          style: GoogleFonts.cinzel(color: const Color(0xFFE5A043)),
        ),
        content: Text(
          'The lobby will auto-fill with bots soon. Do you want to keep waiting?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              isDialogActive = false;
              autoDismissTimer?.cancel();
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
              isDialogActive = false;
              autoDismissTimer?.cancel();
              Navigator.pop(context);
            },
            child: const Text(
              'Wait',
              style: TextStyle(color: Color(0xFFE5A043)),
            ),
          ),
        ],
      ),
    ).then((_) {
      isDialogActive = false;
      autoDismissTimer?.cancel();
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
    _waitTimer?.cancel();
    // If we haven't found a match OR if we manually popped (aborting match found state)
    if (!_isMatchFound || _isManualPop) {
      _handler?.leaveRoom('');
    }
    _controller.dispose();
    _pulseController.dispose();
    _statsSubscription?.cancel();
    _sessionStateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _roomEventSubscription?.cancel();
    _countdownTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _isManualPop = true;
          }
        },
        child: Stack(
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
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final isReconnecting =
        _connectionStatus == ConnectionStatus.reconnecting ||
        _connectionStatus == ConnectionStatus.connecting;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: double.infinity,
        color: isReconnecting ? Colors.orangeAccent : Colors.redAccent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReconnecting ? Icons.sync : Icons.error_outline,
              color: Colors.black,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              isReconnecting ? 'Reconnecting to server...' : 'Connection Lost',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
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
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Padding(
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
                      'Starting in: $_secondsRemaining seconds',
                      style: GoogleFonts.inter(
                        color: _secondsRemaining <= 10
                            ? Colors.redAccent
                            : const Color(0xFFE5A043),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _buildParticipantCard(sortedParticipants[i]),
        ),
      );
    }

    // Add empty slots for remaining spots
    final remainingSlots = maxPlayers - sortedParticipants.length;
    for (int i = 0; i < remainingSlots; i++) {
      slots.add(
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _buildEmptySlot(sortedParticipants.length + i + 1),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      childAspectRatio: 0.68, // Adjusted to prevent overflow
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
            width: 100,
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
}
