import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../session/session.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/config/app_config.dart';
import '../bloc/matchmaking_bloc.dart';
import '../bloc/matchmaking_event.dart';
import '../bloc/matchmaking_state.dart';
import '../widgets/matchmaking_widgets.dart';

class MatchmakingScreen extends StatelessWidget {
  const MatchmakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MatchmakingBloc()..add(StartMatchmaking()),
      child: const _MatchmakingView(),
    );
  }
}

class _MatchmakingView extends StatefulWidget {
  const _MatchmakingView();

  @override
  State<_MatchmakingView> createState() => _MatchmakingViewState();
}

class _MatchmakingViewState extends State<_MatchmakingView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  bool _hasShownTimeoutDialog = false;
  bool _isManualPop = false;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onManualPop() {
    _isManualPop = true;
    context.read<MatchmakingBloc>().add(CancelMatchmaking());
    Navigator.of(context).pop();
  }

  void _showTimeoutDialog() {
    if (!mounted) return;
    _hasShownTimeoutDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
              Navigator.pop(dialogContext);
              _onManualPop();
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Wait',
              style: TextStyle(color: Color(0xFFE5A043)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MatchmakingBloc, MatchmakingState>(
      listener: (context, state) {
        // Swap handler with SessionBloc when connection is established
        if (state.connectionStatus == ConnectionStatus.connected &&
            !state.isConnecting) {
          final bloc = context.read<MatchmakingBloc>();
          context.read<SessionBloc>().add(SessionHandlerSwapped(bloc.handler));
        }

        if (state.isMatchFound) {
          Future.delayed(
            Duration(seconds: AppConfig.instance.matchmakingDelaySeconds),
            () {
              if (context.mounted && !_isManualPop) {
                Navigator.pushReplacementNamed(
                  context,
                  '/session',
                  arguments: {'useWebSocket': true},
                );
              }
            },
          );
        }

        if (state.secondsRemaining <= 15 &&
            state.secondsRemaining > 0 &&
            !_hasShownTimeoutDialog &&
            !state.isMatchFound) {
          _showTimeoutDialog();
        }

        if (state.secondsRemaining <= 5 && state.secondsRemaining > 0) {
          HapticFeedback.selectionClick();
        }

        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (state.error!.contains('Funds')) {
            Navigator.pop(context);
          }
        }
      },
      child: BlocBuilder<MatchmakingBloc, MatchmakingState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) _isManualPop = true;
              },
              child: Stack(
                children: [
                  _buildBackground(),
                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(state),
                        MatchmakingConnectionBanner(
                          status: state.connectionStatus,
                          pulseController: _pulseController,
                        ),
                        const SizedBox(height: 24),
                        _buildStatusInfo(state),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 140,
                          child: MatchmakingOrbit(controller: _controller),
                        ),
                        const SizedBox(height: 32),
                        Expanded(
                          child: _buildParticipantsList(state.participants),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  Widget _buildHeader(MatchmakingState state) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
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
                  'Starting in: ${state.secondsRemaining} seconds',
                  style: GoogleFonts.inter(
                    color: state.secondsRemaining <= 10
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
              onPressed: _onManualPop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfo(MatchmakingState state) {
    return Column(
      children: [
        Text(
          state.isMatchFound ? 'Match Found!' : 'Looking for players...',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Players found: ${state.participants.length} / 5',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFE5A043),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsList(List<Participant> participants) {
    const int maxPlayers = 5;
    final List<Participant> sorted = List.from(participants);
    sorted.sort((a, b) {
      if (a.isMe) return -1;
      if (b.isMe) return 1;
      return 0;
    });

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: maxPlayers,
      itemBuilder: (context, index) {
        if (index < sorted.length) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: ParticipantCard(
              key: ValueKey(sorted[index].id),
              participant: sorted[index],
            ),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: const EmptySlot(),
        );
      },
    );
  }
}
