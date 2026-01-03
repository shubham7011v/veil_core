import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_state.dart';
import '../bloc/session_event.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../widgets/bluff_reveal_overlay.dart';
import '../widgets/flying_cards_layer.dart';
import '../widgets/session_top_bar.dart';
import '../widgets/opponent_carousel.dart';
import '../widgets/game_table_view.dart';
import '../widgets/session_background.dart';
import '../widgets/game_win_overlay.dart';
import '../widgets/session_staging_area.dart';
import '../widgets/session_bottom_controls.dart';

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
  final GlobalKey _stagingKey = GlobalKey();
  final List<FlyingCard> _flyingCards = [];

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
    int retryCount = 0,
    bool randomOffset = false,
    Offset? customStartOffset,
    Offset? customEndOffset,
  }) {
    if (!mounted) return;

    final sourceKey = sourceId == 'pile'
        ? _pileKey
        : (sourceId == 'staging' ? _stagingKey : _avatarKeys[sourceId]);
    final targetKey = targetId == 'pile'
        ? _pileKey
        : (targetId == 'staging' ? _stagingKey : _avatarKeys[targetId]);

    // Allow null keys if custom offsets are provided
    if ((sourceKey == null && customStartOffset == null) ||
        (targetKey == null && customEndOffset == null)) {
      return;
    }

    // Use addPostFrameCallback to ensure keys are rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Offset start =
          customStartOffset ??
          (sourceKey != null ? _getCenterOffset(sourceKey) : Offset.zero);
      Offset end =
          customEndOffset ??
          (targetKey != null ? _getCenterOffset(targetKey) : Offset.zero);

      if (randomOffset &&
          customStartOffset == null &&
          customEndOffset == null) {
        final rnd = math.Random();
        // Wider range for more messy "shuffle" look
        start += Offset(
          rnd.nextDouble() * 200 - 100,
          rnd.nextDouble() * 200 - 100,
        );
        end += Offset(rnd.nextDouble() * 80 - 40, rnd.nextDouble() * 80 - 40);
      }

      if (start == Offset.zero || end == Offset.zero) {
        if (retryCount < 15) {
          // Retry more times if the layout isn't ready
          Future.delayed(const Duration(milliseconds: 100), () {
            _triggerCardAnimation(
              sourceId: sourceId,
              targetId: targetId,
              count: count,
              retryCount: retryCount + 1,
              randomOffset: randomOffset,
              customStartOffset: customStartOffset,
              customEndOffset: customEndOffset,
            );
          });
        }
        return;
      }

      final id =
          DateTime.now().microsecondsSinceEpoch.toString() +
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

  void _handleGameEvents(
    engine.SessionEventType event,
    SessionBlocState state,
  ) {
    debugPrint("SessionScreen: Handling Event -> $event");
    switch (event) {
      case engine.SessionEventType.cardsPlayed:
        if (state.lastEventActorId != null) {
          final isMe = state.lastEventActorId == 'me';
          _triggerCardAnimation(
            sourceId: isMe ? 'staging' : state.lastEventActorId!,
            targetId: 'pile',
            count: state.lastEventCardCount,
          );
        }
        break;
      case engine.SessionEventType.cardsPickedUp:
        if (state.lastEventActorId != null) {
          _triggerCardAnimation(
            sourceId: 'pile',
            targetId: state.lastEventActorId!,
            count: state.lastEventCardCount,
          );
        }
        break;
      case engine.SessionEventType.shuffling:
        // Clean distribution: Fly cards from pile directly to each player
        final participants = state.engineState.participants;
        if (participants.isEmpty) return;

        final totalCards = 52;
        final cardsPerPlayer = totalCards ~/ participants.length;

        // Distribute cards to all players simultaneously
        for (var participant in participants) {
          _triggerCardAnimation(
            sourceId: 'pile',
            targetId: participant.id,
            count: cardsPerPlayer,
          );
        }
        break;
      case engine.SessionEventType.cardStaged:
        // No animation - cards instantly appear in staging area
        break;
      case engine.SessionEventType.pileDiscarded:
        // Fly cards off-screen in random horizontal directions
        final rnd = math.Random();
        final size = MediaQuery.of(context).size;
        final pileOffset = _getCenterOffset(_pileKey);

        if (pileOffset == Offset.zero) return;

        for (int i = 0; i < 12; i++) {
          final targetPoint = Offset(
            rnd.nextDouble() < 0.5 ? -150 : size.width + 150,
            rnd.nextDouble() * size.height,
          );
          Future.delayed(Duration(milliseconds: i * 40), () {
            _triggerCardAnimation(
              sourceId: 'pile',
              targetId: 'offscreen',
              customStartOffset: pileOffset,
              customEndOffset: targetPoint,
            );
          });
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
          curr.lastEvent != engine.SessionEventType.none &&
          prev.lastEventTimestamp != curr.lastEventTimestamp,
      listener: (context, state) {
        if (state.lastEvent != engine.SessionEventType.none) {
          _handleGameEvents(state.lastEvent, state);
        }
      },
      child: BlocBuilder<SessionBloc, SessionBlocState>(
        builder: (context, state) {
          return PopScope(
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                context.read<SessionBloc>().add(const SessionResetRequested());
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Stack(
                children: [
                  const SessionBackground(),
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
                        const SizedBox(height: 16),

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
                              key: _stagingKey,
                              state: state,
                              myAvatarKey: _avatarKeys['me']!,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),

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
                          engine.SessionPhase.finished &&
                      state.engineState.winnerId != null)
                    GameWinOverlay(
                      winnerId: state.engineState.winnerId!,
                      winnerName: state.getPlayerName(
                        state.engineState.winnerId!,
                      ),
                      onBackToHome: () {
                        context.read<SessionBloc>().add(
                          const SessionResetRequested(),
                        );
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                    ),

                  if (state.isRevealingBluff && state.lastMove != null)
                    BluffRevealOverlay(
                      cards: state.lastMove!.actualUnits,
                      declaredRank: state.lastMove!.declaredRank,
                    ),

                  // Action Overlays (Flying Cards, Badges) - MUST BE ON TOP
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FlyingCardsLayer(activeAnimations: _flyingCards),
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
}
