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
import '../widgets/compact_match_log.dart';
import '../../../../core/theme/colors.dart';
import 'package:veil_core/features/voice/presentation/widgets/voice_overlay.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';
import '../../../game/presentation/widgets/chat_widget.dart';
import '../../../game/presentation/widgets/emoji_picker.dart';
import '../../../../core/config/feature_flags.dart';
import '../widgets/floating_emoji_layer.dart';

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
  bool _showChat = false;
  bool _showEmoji = false;
  final List<FloatingEmoji> _activeEmojis = [];

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
    // Leave online room to clean up server state
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['useWebSocket'] == true) {
      try {
        di.sl.webSocketSessionHandler.leaveRoom('');
      } catch (e) {
        debugPrint('Error leaving room on dispose: $e');
      }
    }
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

      if (randomOffset) {
        final rnd = math.Random();
        if (customStartOffset == null) {
          start += Offset(
            rnd.nextDouble() * 40 - 20,
            rnd.nextDouble() * 40 - 20,
          );
        }
        end += Offset(rnd.nextDouble() * 40 - 20, rnd.nextDouble() * 40 - 20);
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
        // Check user setting for shuffle animation
        final shouldAnimate =
            di.sl.storageService.getBool('pref_shuffle_animation') ?? true;

        if (!shouldAnimate) break;

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
      case engine.SessionEventType.emojiReceived:
        final senderId = state.lastEventActorId;
        if (senderId != null) {
          final isMe = senderId == 'me';
          final sourceKey = isMe ? _avatarKeys['me'] : _avatarKeys[senderId];

          if (sourceKey != null) {
            final emojiChar =
                state.chatMessages.lastWhere(
                  (m) => m['type'] == 'emoji',
                )['emojiId'] ??
                '😊';
            final position = _getCenterOffset(sourceKey);
            final id = DateTime.now().microsecondsSinceEpoch.toString();

            setState(() {
              _activeEmojis.add(
                FloatingEmoji(id: id, emoji: emojiChar, position: position),
              );
            });

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _activeEmojis.removeWhere((e) => e.id == id);
                });
              }
            });
          }
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
        // Handle Failures
        if (state.failure != null) {
          context.read<AppNotificationBloc>().add(
            ShowErrorNotification(state.failure!.message),
          );
          // Auto-clear error after showing notification
          context.read<SessionBloc>().add(const SessionErrorCleared());
        }

        if (state.lastEvent != engine.SessionEventType.none) {
          _handleGameEvents(state.lastEvent, state);
        }
      },
      child: BlocBuilder<SessionBloc, SessionBlocState>(
        builder: (context, state) {
          final showSpectatorView = state.engineState.isSpectator;

          Widget content = PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              context.read<SessionBloc>().add(const SessionResetRequested());
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Stack(
                children: [
                  const SessionBackground(),
                  SafeArea(
                    child: Column(
                      children: [
                        // Top Bar
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
                            child: SessionTopBar(
                              state: state,
                              onChatTap: () => setState(() {
                                _showChat = !_showChat;
                                if (_showChat) _showEmoji = false;
                              }),
                            ),
                          ),
                        ),

                        // Opponents
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

                        // Center Pile
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

                        // Staging Area
                        if (!showSpectatorView)
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

                        // Bottom Controls
                        if (!showSpectatorView)
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
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              child: const Text(
                                'SPECTATING',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
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
                      coinsEarned: state.engineState.winnerId == 'me'
                          ? 400 // Winner gets pot (5 players × 100 - their boot)
                          : -100, // Loser paid boot
                      gameLog: state.gameLog,
                      matchStats: state.gameStartTime != null
                          ? state.matchStats.copyWith(
                              matchDuration: DateTime.now().difference(
                                state.gameStartTime!,
                              ),
                            )
                          : state.matchStats,
                      onBackToHome: () {
                        context.read<SessionBloc>().add(
                          const SessionResetRequested(),
                        );
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                      onPlayAgain: () {
                        // Reset and navigate back to matchmaking
                        context.read<SessionBloc>().add(
                          const SessionResetRequested(),
                        );
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/matchmaking',
                          (route) => false,
                        );
                      },
                    ),

                  if (state.isRevealingBluff && state.lastMove != null)
                    BluffRevealOverlay(
                      cards: state.lastMove!.actualUnits,
                      declaredRank: state.lastMove!.declaredRank,
                    ),

                  Positioned.fill(
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          FlyingCardsLayer(activeAnimations: _flyingCards),
                          if (FeatureFlags.enableGameChat)
                            FloatingEmojiLayer(activeEmojis: _activeEmojis),
                        ],
                      ),
                    ),
                  ),

                  // Voice Overlay - only when voice is enabled
                  if (di.sl.voiceSessionHandler != null &&
                      FeatureFlags.enableVoiceChat)
                    Positioned.fill(
                      child: VoiceOverlay(
                        sessionHandler: di.sl.voiceSessionHandler!,
                      ),
                    ),

                  // Compact Match Log - bottom right
                  if (state.gameLog.isNotEmpty && !showSpectatorView)
                    Positioned(
                      bottom: 120,
                      right: 16,
                      child: CompactMatchLog(gameLog: state.gameLog),
                    ),
                ],
              ),
            ),
          );

          return Stack(
            children: [
              content,

              // Chat Overlay
              if (_showChat && FeatureFlags.enableGameChat)
                Positioned(
                  bottom: 100,
                  left: 16,
                  child: ChatWidget(
                    onClose: () => setState(() => _showChat = false),
                  ),
                ),

              // Emoji Overlay
              if (_showEmoji && FeatureFlags.enableGameChat)
                Positioned(
                  top:
                      MediaQuery.of(context).size.height / 2 -
                      140, // Centered vertically
                  right: 16,
                  child: EmojiPicker(
                    onClose: () => setState(() => _showEmoji = false),
                  ),
                ),

              // Emoji Toggle Button (Middle Right)
              if (!showSpectatorView && FeatureFlags.enableGameChat)
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).size.height / 2 - 24,
                  child: FloatingActionButton.small(
                    heroTag: 'emoji_btn_fixed',
                    backgroundColor: AppColors.surfaceLight,
                    onPressed: () => setState(() {
                      _showEmoji = !_showEmoji;
                      if (_showEmoji) _showChat = false;
                    }),
                    child: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
