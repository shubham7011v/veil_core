import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/session_bloc.dart';
import '../../bloc/session_state.dart';
import '../../models/session_enums.dart';
import '../../models/session_state.dart' as engine;
import '../../widgets/bluff_reveal_overlay.dart';
import '../../widgets/flying_cards_layer.dart';
import '../../widgets/session_top_bar.dart';
import '../../widgets/opponent_carousel.dart';
import '../../widgets/game_table_view.dart';
import '../../widgets/session_staging_area.dart';
import '../../widgets/session_bottom_controls.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;

  final Map<String, GlobalKey> _avatarKeys = {
    'me': GlobalKey(),
    'p1': GlobalKey(),
    'p2': GlobalKey(),
    'p3': GlobalKey(),
    'p4': GlobalKey(),
    'p5': GlobalKey(),
    'p6': GlobalKey(),
    'p7': GlobalKey(),
    'p8': GlobalKey(),
    'p9': GlobalKey(),
  };
  final GlobalKey _pileKey = GlobalKey();
  final List<FlyingCard> _flyingCards = [];
  Color? _flashColor;
  final List<Widget> _particles = [];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Offset _getCenterOffset(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  }

  void _triggerCardAnimation({
    required String sourceId,
    required String targetId,
    int count = 1,
  }) {
    if (!mounted) return;

    final sourceKey = sourceId == 'pile' ? _pileKey : _avatarKeys[sourceId];
    final targetKey = targetId == 'pile' ? _pileKey : _avatarKeys[targetId];

    if (sourceKey == null || targetKey == null) return;

    // Use addPostFrameCallback to ensure keys are rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final start = _getCenterOffset(sourceKey);
      final end = _getCenterOffset(targetKey);

      if (start == Offset.zero || end == Offset.zero) return;

      final id =
          DateTime.now().millisecondsSinceEpoch.toString() +
          sourceId +
          targetId;
      setState(() {
        _flyingCards.add(
          FlyingCard(id: id, start: start, end: end, count: count),
        );
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _flyingCards.removeWhere((anim) => anim.id == id);
          });
        }
      });
    });
  }

  void _handleGameEvents(SessionEventType event, SessionBlocState state) {
    debugPrint("SessionScreen: Handling Event -> $event");
    switch (event) {
      case SessionEventType.cardsPlayed:
        if (state.lastEventActorId != null) {
          _triggerCardAnimation(
            sourceId: state.lastEventActorId!,
            targetId: 'pile',
            count: state.lastEventCardCount,
          );
        }
        break;
      case SessionEventType.bluffResolved:
        if (state.lastEventActorId != null) {
          _triggerCardAnimation(
            sourceId: 'pile',
            targetId: state.lastEventActorId!,
            count: state.lastEventCardCount,
          );
        }
        break;
      case SessionEventType.cardsDealt:
        for (var p in state.engineState.participants) {
          _triggerCardAnimation(
            sourceId: 'pile',
            targetId: p.id,
            count: 4, // Visual representation of deal
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionBlocState>(
      listenWhen: (prev, curr) =>
          prev.lastEvent != curr.lastEvent ||
          (curr.lastEvent != SessionEventType.none &&
              prev.lastEventActorId != curr.lastEventActorId),
      listener: (context, state) {
        if (state.lastEvent != SessionEventType.none) {
          _handleGameEvents(state.lastEvent, state);
        }
      },
      child: BlocBuilder<SessionBloc, SessionBlocState>(
        builder: (context, state) {
          final bloc = context.read<SessionBloc>();
          final handler = bloc.handler;

          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [Color(0xFF2A1E17), Color(0xFF0D0D0D)],
                      ),
                    ),
                  ),
                ),
                if (_flashColor != null)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      color: _flashColor,
                    ),
                  ),
                SafeArea(
                  child: Column(
                    children: [
                      // Top Bar (0.0 - 0.4)
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, -0.5),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entryController,
                                curve: const Interval(
                                  0.0,
                                  0.4,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(
                              0.0,
                              0.4,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: SessionTopBar(state: state),
                        ),
                      ),

                      // Opponents (0.1 - 0.5)
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, -0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entryController,
                                curve: const Interval(
                                  0.1,
                                  0.5,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(
                              0.1,
                              0.5,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: OpponentCarousel(
                            state: state,
                            avatarKeys: _avatarKeys,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Center Pile + Claim Badge
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: _entryController,
                                    curve: const Interval(
                                      0.2,
                                      0.7,
                                      curve: Curves.elasticOut,
                                    ),
                                  ),
                                  child: GameTableView(
                                    state: state,
                                    pileKey: _pileKey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Staging Area (0.4 - 0.8)
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entryController,
                                curve: const Interval(
                                  0.4,
                                  0.8,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(
                              0.4,
                              0.8,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: SessionStagingArea(
                            state: state,
                            myAvatarKey: _avatarKeys['me']!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Bottom Controls (0.5 - 1.0)
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entryController,
                                curve: const Interval(
                                  0.5,
                                  1.0,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(
                              0.5,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: SessionBottomControls(
                            state: state,
                            myAvatarKey: _avatarKeys['me']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (state.engineState.currentPhase ==
                    engine.SessionPhase.finished)
                  _buildWinOverlay(context, state),

                // Action Overlays (Flying Cards, Badges)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FlyingCardsLayer(
                      activeAnimations: _flyingCards,
                      onComplete: () {},
                    ),
                  ),
                ),

                // Particle Layer
                ..._particles,

                if (handler.isRevealingBluff && handler.lastMove != null)
                  BluffRevealOverlay(
                    cards: handler.lastMove!.actualUnits,
                    declaredRank: handler.lastMove!.declaredRank,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWinOverlay(BuildContext context, SessionBlocState state) {
    final bloc = context.read<SessionBloc>();
    final winnerName =
        bloc.handler.pNames[state.engineState.winnerId] ?? "Someone";
    final isMe = state.engineState.winnerId == 'me';

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMe ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
              size: 100,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(height: 24),
            Text(
              isMe ? "VICTORY!" : "GAME OVER",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMe
                  ? "You have cleared all your cards!"
                  : "$winnerName has won the game.",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  "BACK TO HOME",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
