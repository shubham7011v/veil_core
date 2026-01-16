import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_state.dart';
import '../bloc/session_event.dart';
import '../../../../core/engine/engine.dart' as engine;
// import '../widgets/bluff_reveal_overlay.dart'; // Now using simple popup
import '../widgets/flying_cards_layer.dart';
import '../widgets/session_top_bar.dart';
import '../widgets/opponent_carousel.dart';
import '../widgets/game_table_view.dart';
import '../widgets/session_background.dart';
import '../widgets/game_win_overlay.dart';
import '../widgets/session_staging_area.dart';
import '../widgets/session_bottom_controls.dart';
import '../../../../core/theme/colors.dart';
import 'package:veil_core/features/voice/presentation/widgets/voice_overlay.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';
import '../../../game/presentation/widgets/chat_widget.dart';
import '../../../game/presentation/widgets/emoji_picker.dart';
import '../../../../core/config/feature_flags.dart';
import '../widgets/floating_emoji_layer.dart';
import '../utils/session_constants.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;

  final Map<String, GlobalKey> _avatarKeys = {SessionIds.me: GlobalKey()};
  final GlobalKey _pileKey = GlobalKey();
  final GlobalKey _stagingKey = GlobalKey();
  final List<FlyingCard> _flyingCards = [];
  bool _showChat = false;
  bool _showEmoji = false;
  final List<FloatingEmoji> _activeEmojis = [];
  bool? _isWebSocket;
  bool _isNavigating = false;
  // Turn Popup State
  String? _turnPopupText;
  Color _turnPopupColor = const Color(0xFFFFD700); // Default Gold
  Timer? _turnPopupTimer;
  // Track previous active player ID for turn change detection
  String? _previousActivePlayerId; // Tracks state updates for popups
  String? _visualActivePlayerId; // Tracks visual updates for UI masking
  Timer? _visualUpdateTimer;
  int _lastHandledEventTimestamp = 0; // Prevent duplicate event handling

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: SessionDurations.entryAnimationDuration,
    );
    AppLogger.sessionEvent('Screen initialized');
    _entryController.forward();

    // Check for missed initial events (e.g. shuffling)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<SessionBloc>().state;
      if (state.lastEvent == engine.SessionEventType.shuffling) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final eventTime = state.lastEventTimestamp;
        // If event happened within last 10 seconds, replay it
        if (now - eventTime < 10000) {
          AppLogger.sessionEvent('Replaying missed shuffling event');
          _handleGameEvents(engine.SessionEventType.shuffling, state);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isWebSocket == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _isWebSocket = args is Map && args['useWebSocket'] == true;
    }
  }

  @override
  void dispose() {
    // Leave online room to clean up server state
    if (_isWebSocket == true) {
      try {
        AppLogger.sessionEvent('Leaving online room on dispose');
        di.sl.webSocketSessionHandler.leaveRoom('');
      } catch (e) {
        AppLogger.sessionError('Error leaving room on dispose', exception: e);
      }
    }
    _turnPopupTimer?.cancel();
    _visualUpdateTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  Offset _getCenterOffset(GlobalKey key) {
    if (key.currentContext == null) return Offset.zero;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  }

  void _updateAvatarKeys(SessionBlocState state) {
    // Ensure all participants have GlobalKeys
    for (var p in state.engineState.participants) {
      if (p.isMe) {
        // Map my actual ID to the SessionIds.me key used by HandView
        _avatarKeys[p.id] = _avatarKeys[SessionIds.me]!;
        // Also map sessionId to the same key
        if (p.sessionId != null) {
          _avatarKeys[p.sessionId!] = _avatarKeys[SessionIds.me]!;
        }
      } else {
        // If we don't have a key for this participant, create one
        if (!_avatarKeys.containsKey(p.id)) {
          _avatarKeys[p.id] = GlobalKey();
        }
        // Map sessionId to the same key so we can find them by either ID
        if (p.sessionId != null && _avatarKeys.containsKey(p.id)) {
          _avatarKeys[p.sessionId!] = _avatarKeys[p.id]!;
        }
      }
    }
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

    final sourceKey = sourceId == SessionIds.pile
        ? _pileKey
        : (sourceId == SessionIds.staging
              ? _stagingKey
              : _avatarKeys[sourceId]);
    final targetKey = targetId == SessionIds.pile
        ? _pileKey
        : (targetId == SessionIds.staging
              ? _stagingKey
              : _avatarKeys[targetId]);

    // FALLBACK: If we can't find keys, try to infer sensible defaults
    // e.g. if target is 'pile' but key is missing, use screen center
    // if source is 'staging' but missing, use bottom center
    final screenSize = MediaQuery.of(context).size;

    // Use addPostFrameCallback to ensure keys are rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Offset start =
          customStartOffset ??
          (sourceKey != null ? _getCenterOffset(sourceKey) : Offset.zero);

      // Fallback for start position
      if (start == Offset.zero) {
        if (sourceId == SessionIds.pile) {
          start = Offset(screenSize.width / 2, screenSize.height / 2);
        } else if (sourceId == SessionIds.staging) {
          start = Offset(screenSize.width / 2, screenSize.height - 100);
        } else {
          // Default for Opponents/Unknown: Top Center (Opponent Carousel area)
          start = Offset(screenSize.width / 2, 80);
        }
      }

      Offset end =
          customEndOffset ??
          (targetKey != null ? _getCenterOffset(targetKey) : Offset.zero);

      // Fallback for end position
      if (end == Offset.zero) {
        if (targetId == SessionIds.pile) {
          end = Offset(screenSize.width / 2, screenSize.height / 2);
        } else if (targetId == SessionIds.staging) {
          end = Offset(screenSize.width / 2, screenSize.height - 100);
        } else {
          // Default for Opponents/Unknown: Top Center
          end = Offset(screenSize.width / 2, 80);
        }
      }

      AppLogger.sessionEvent(
        '$sourceId -> $targetId animation started',
        data: {
          'source': sourceId,
          'target': targetId,
          'start': start,
          'end': end,
        },
      );

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
        if (retryCount < 30) {
          // Retry more times if the layout isn't ready
          Future.delayed(const Duration(milliseconds: 50), () {
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
    AppLogger.sessionEvent('Handling event: $event');
    switch (event) {
      case engine.SessionEventType.passed:
        if (state.lastEventActorId != null) {
          final isMe = state.lastEventActorId == SessionIds.me;
          HapticFeedback.lightImpact();

          // Get clean player name from participant object
          String name;
          if (isMe) {
            name = "YOU";
          } else {
            try {
              final participant = state.engineState.participants.firstWhere(
                (p) => p.sessionId == state.lastEventActorId,
              );
              name = participant.name.split(' ').first.toUpperCase();
              AppLogger.sessionEvent(
                'Pass: Found participant: ${participant.name}',
              );
            } catch (e) {
              AppLogger.sessionError(
                'Pass: No participant found',
                exception: e,
              );
              AppLogger.info(
                'Available sessionIds: ${state.engineState.participants.map((p) => "${p.name}:${p.sessionId}").join(", ")}',
              );
              name = "PLAYER";
            }
          }

          _showTurnPopup("$name PASSED", Colors.white);
        }
        break;
      case engine.SessionEventType.bluffCalled:
        // Show who called the bluff
        if (state.lastEventActorId != null) {
          HapticFeedback.mediumImpact();

          // Get challenger name
          String name;
          final isMe = state.lastEventActorId == SessionIds.me;

          if (isMe) {
            name = "YOU";
          } else {
            try {
              final participant = state.engineState.participants.firstWhere(
                (p) => p.sessionId == state.lastEventActorId,
              );
              name = participant.name.split(' ').first.toUpperCase();
              AppLogger.sessionEvent(
                'Bluff: Found participant: ${participant.name}',
              );
            } catch (e) {
              AppLogger.sessionError(
                'Bluff: No participant found',
                exception: e,
              );
              AppLogger.info(
                'Available sessionIds: ${state.engineState.participants.map((p) => "${p.name}:${p.sessionId}").join(", ")}',
              );
              name = "PLAYER";
            }
          }

          _showTurnPopup("$name CALLS BLUFF", Colors.orange);
        }
        break;
      case engine.SessionEventType.cardsPlayed:
        // Ensure strictly positive count and valid actor
        if (state.lastEventActorId != null && state.lastEventCardCount > 0) {
          final isMe = state.lastEventActorId == SessionIds.me;
          AppLogger.sessionEvent(
            'CardsPlayed',
            data: {
              'actor': state.lastEventActorId,
              'isMe': isMe,
              'count': state.lastEventCardCount,
            },
          );
          HapticFeedback.selectionClick();
          _triggerCardAnimation(
            sourceId: isMe ? SessionIds.staging : state.lastEventActorId!,
            targetId: SessionIds.pile,
            count: state.lastEventCardCount,
          );
        }
        break;
      case engine.SessionEventType.cardsPickedUp:
        // Bluff/Challenge Loser picking up cards
        if (state.lastEventActorId != null) {
          HapticFeedback.mediumImpact();

          // Determine bluff result color
          // isBluffSuccessful == true: Bluff was caught (Red)
          // isBluffSuccessful == false: No bluff, genuine cards (Green)
          final Color feedbackColor;
          final String feedbackText;
          AppLogger.sessionEvent(
            'PickedUp',
            data: {'isBluffSuccessful': state.isBluffSuccessful},
          );

          if (state.isBluffSuccessful == true) {
            feedbackColor = Colors.red;
            feedbackText = "BLUFF CAUGHT!";
          } else if (state.isBluffSuccessful == false) {
            feedbackColor = Colors.green;
            feedbackText = "NO BLUFF!";
          } else {
            // Fallback if isBluffSuccessful is null
            feedbackColor = Colors.orange;
            feedbackText = "CARDS PICKED UP";
          }
          AppLogger.sessionEvent('Showing result popup: $feedbackText');
          _showTurnPopup(feedbackText, feedbackColor);

          // Animate from Pile -> Loser
          _triggerCardAnimation(
            sourceId: SessionIds.pile,
            targetId: state.lastEventActorId!,
            count: state.lastEventCardCount,
          );
        }
        break;
      case engine.SessionEventType.shuffling:
        HapticFeedback.lightImpact();
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
            sourceId: SessionIds.pile,
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
              sourceId: SessionIds.pile,
              targetId: SessionIds.offscreen,
              customStartOffset: pileOffset,
              customEndOffset: targetPoint,
            );
          });
        }
        break;
      case engine.SessionEventType.emojiReceived:
        final senderId = state.lastEventActorId;
        if (senderId != null) {
          final isMe = senderId == SessionIds.me;
          final sourceKey = isMe
              ? _avatarKeys[SessionIds.me]
              : _avatarKeys[senderId];

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

  void _showTurnPopup(String text, [Color color = const Color(0xFFFFD700)]) {
    _turnPopupTimer?.cancel();
    setState(() {
      _turnPopupText = text;
      _turnPopupColor = color;
    });
    _turnPopupTimer = Timer(SessionDurations.turnPopupDuration, () {
      if (mounted) {
        setState(() {
          _turnPopupText = null;
        });
      }
    });
  }

  Future<void> _leaveGameAndNavigate(String routeName) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    // ✅ FORCE LEAVE: Explicitly tell server to remove us immediately
    if (_isWebSocket == true) {
      try {
        AppLogger.sessionEvent('Manual exit - sending LEAVE_ROOM');
        di.sl.webSocketSessionHandler.leaveRoom('');
        // Add small delay to allow message to hit network buffer
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        AppLogger.sessionError('Failed to send LEAVE_ROOM', exception: e);
      }
    }

    // ✅ Cleanup local state to prevent memory leaks
    _avatarKeys.removeWhere((key, _) => key != SessionIds.me);
    _flyingCards.clear();
    _activeEmojis.clear();
    _turnPopupTimer?.cancel();
    _turnPopupText = null;
    _previousActivePlayerId = null;

    if (!mounted) return;
    context.read<SessionBloc>().add(const SessionResetRequested());
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionBlocState>(
      listenWhen: (prev, curr) =>
          (curr.lastEvent != engine.SessionEventType.none &&
              prev.lastEventTimestamp != curr.lastEventTimestamp) ||
          prev.engineState.activeParticipantId !=
              curr.engineState.activeParticipantId,
      listener: (context, state) {
        _updateAvatarKeys(state);

        // Handle Turn Change Feedback using tracked previous ID
        final currentActiveId = state.engineState.activeParticipantId;
        if (currentActiveId != _previousActivePlayerId &&
            currentActiveId != null &&
            currentActiveId.isNotEmpty) {
          if (currentActiveId == SessionIds.me) {
            HapticFeedback.mediumImpact();
            _showTurnPopup("YOUR TURN");
          } else {
            HapticFeedback.lightImpact();
            final name = state.getPlayerName(currentActiveId);
            _showTurnPopup("${name.toUpperCase()}'S TURN");
          }
          // Update tracked ID after handling
          _previousActivePlayerId = currentActiveId;
        }

        // Handle Failures
        if (state.failure != null) {
          context.read<AppNotificationBloc>().add(
            ShowErrorNotification(state.failure!.message),
          );
          // Auto-clear error after showing notification
          context.read<SessionBloc>().add(const SessionErrorCleared());
        }

        if (state.lastEvent != engine.SessionEventType.none &&
            state.lastEventTimestamp != _lastHandledEventTimestamp) {
          // Only handle if this specific event timestamp hasn't been processed
          _lastHandledEventTimestamp = state.lastEventTimestamp;
          _handleGameEvents(state.lastEvent, state);
        }

        // SYNC VISUALS: Delay visual update if cards were just played
        // This prevents the "Active Player" highlight from jumping to the next player
        // while the previous player's cards are still flying.
        _visualUpdateTimer?.cancel();
        if (state.lastEvent == engine.SessionEventType.cardsPlayed) {
          // Keep OLD ID (don't update _visualActivePlayerId yet)
          // Schedule update after animation completes (approx 1s)
          _visualUpdateTimer = Timer(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _visualActivePlayerId = state.engineState.activeParticipantId;
              });
            }
          });
        } else {
          // Immediate update for other events
          setState(() {
            _visualActivePlayerId = state.engineState.activeParticipantId;
          });
        }
      },
      child: BlocBuilder<SessionBloc, SessionBlocState>(
        builder: (context, state) {
          // Initialize visual ID on first build if null
          _visualActivePlayerId ??= state.engineState.activeParticipantId;

          // Create masked state for UI rendering
          final visualState = state.copyWith(
            engineState: state.engineState.copyWith(
              activeParticipantId:
                  _visualActivePlayerId ??
                  state.engineState.activeParticipantId,
            ),
          );

          // Note: _updateAvatarKeys is in listener, not here (avoid side effects in build)

          final showSpectatorView = state.engineState.isSpectator;

          Widget content = PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;

              // ✅ Handle System Back Button: Show dialog or leave
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text(
                    'Leave Game?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Are you sure you want to leave the game?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Leave',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldLeave == true) {
                _leaveGameAndNavigate('/home');
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Stack(
                children: [
                  // ... (background and SafeArea) ...
                  const SessionBackground(),
                  SafeArea(
                    child: Column(
                      children: [
                        // Top Bar
                        SlideTransition(
                          // ...
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
                            // ...
                            opacity: CurvedAnimation(
                              parent: _entryController,
                              curve: const Interval(
                                0.0,
                                0.4,
                                curve: Curves.easeOut,
                              ),
                            ),
                            child: SessionTopBar(
                              state: visualState,
                              onChatTap: () => setState(() {
                                _showChat = !_showChat;
                                if (_showChat) _showEmoji = false;
                              }),
                            ),
                          ),
                        ),
                        // ... (Opponents, Pile, Staging, Bottom Controls) ...
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
                              state: visualState,
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
                                    state: visualState,
                                    pileKey: _pileKey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Feedback Popup OR Staging Area
                        if (_turnPopupText != null)
                          Container(
                            height: 120, // Approximate height of staging area
                            alignment: Alignment.center,
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 300),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.9 + (0.1 * value),
                                  child: Opacity(
                                    opacity: value,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 200,
                                        maxWidth: 320,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 18,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.black.withValues(
                                              alpha: 0.95,
                                            ),
                                            Colors.black.withValues(
                                              alpha: 0.85,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _turnPopupColor,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _turnPopupColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 24,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _turnPopupText!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _turnPopupColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3,
                                          shadows: [
                                            Shadow(
                                              color: _turnPopupColor.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else if (!showSpectatorView)
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
                                state: visualState,
                                myAvatarKey: _avatarKeys[SessionIds.me]!,
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
                                state: visualState,
                                myAvatarKey: _avatarKeys[SessionIds.me]!,
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
                      coinsEarned: state.engineState.winnerId == SessionIds.me
                          ? 400
                          : -100,
                      gameLog: state.gameLog,
                      matchStats: state.gameStartTime != null
                          ? state.matchStats.copyWith(
                              matchDuration: DateTime.now().difference(
                                state.gameStartTime!,
                              ),
                            )
                          : state.matchStats,
                      onBackToHome: () => _leaveGameAndNavigate('/home'),
                      onPlayAgain: () => _leaveGameAndNavigate('/matchmaking'),
                    ),

                  // Bluff reveal now uses simple popup instead of full-screen overlay
                  // if (state.isRevealingBluff && state.lastMove != null)
                  //   BluffRevealOverlay(
                  //     cards: state.lastMove!.actualUnits,
                  //     declaredRank: state.lastMove!.declaredRank,
                  //   ),
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

                  // Voice Overlay
                  if (di.sl.voiceSessionHandler != null &&
                      FeatureFlags.enableVoiceChat)
                    Positioned.fill(
                      child: VoiceOverlay(
                        sessionHandler: di.sl.voiceSessionHandler!,
                      ),
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
