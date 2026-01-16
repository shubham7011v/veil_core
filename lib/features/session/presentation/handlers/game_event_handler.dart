import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../bloc/session_state.dart';
import '../utils/session_constants.dart';
import '../managers/card_animation_manager.dart';
import '../managers/turn_popup_manager.dart';
import '../widgets/floating_emoji_layer.dart';
import '../../../../core/di/service_locator.dart' as di;

/// Handles all game events and delegates to appropriate managers
/// Extracted from session_screen.dart to improve separation of concerns
class GameEventHandler {
  final CardAnimationManager cardAnimations;
  final TurnPopupManager turnPopups;
  final void Function(VoidCallback fn) setState;
  final List<FloatingEmoji> activeEmojis;

  GameEventHandler({
    required this.cardAnimations,
    required this.turnPopups,
    required this.setState,
    required this.activeEmojis,
  });

  /// Handle a game event by type
  void handleEvent(
    BuildContext context,
    engine.SessionEventType event,
    SessionBlocState state,
  ) {
    AppLogger.sessionEvent('Handling event: $event');
    switch (event) {
      case engine.SessionEventType.passed:
        _handlePassed(context, state);
        break;
      case engine.SessionEventType.bluffCalled:
        _handleBluffCalled(context, state);
        break;
      case engine.SessionEventType.cardsPlayed:
        _handleCardsPlayed(context, state);
        break;
      case engine.SessionEventType.cardsPickedUp:
        _handleCardsPickedUp(context, state);
        break;
      case engine.SessionEventType.shuffling:
        _handleShuffling(context, state);
        break;
      case engine.SessionEventType.cardStaged:
        // No animation - cards instantly appear in staging area
        break;
      case engine.SessionEventType.pileDiscarded:
        _handlePileDiscarded(context, state);
        break;
      case engine.SessionEventType.emojiReceived:
        _handleEmojiReceived(context, state);
        break;
      default:
        break;
    }
  }

  void _handlePassed(BuildContext context, SessionBlocState state) {
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
          AppLogger.sessionError('Pass: No participant found', exception: e);
          AppLogger.info(
            'Available sessionIds: ${state.engineState.participants.map((p) => "${p.name}:${p.sessionId}").join(", ")}',
          );
          name = "PLAYER";
        }
      }

      turnPopups.showPopup("$name PASSED", Colors.white);
    }
  }

  void _handleBluffCalled(BuildContext context, SessionBlocState state) {
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
          AppLogger.sessionError('Bluff: No participant found', exception: e);
          AppLogger.info(
            'Available sessionIds: ${state.engineState.participants.map((p) => "${p.name}:${p.sessionId}").join(", ")}',
          );
          name = "PLAYER";
        }
      }

      turnPopups.showPopup("$name CALLS BLUFF", Colors.orange);
    }
  }

  void _handleCardsPlayed(BuildContext context, SessionBlocState state) {
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
      cardAnimations.triggerCardAnimation(
        context: context,
        sourceId: isMe ? SessionIds.staging : state.lastEventActorId!,
        targetId: SessionIds.pile,
        count: state.lastEventCardCount,
      );
    }
  }

  void _handleCardsPickedUp(BuildContext context, SessionBlocState state) {
    if (state.lastEventActorId != null) {
      HapticFeedback.mediumImpact();

      // Determine bluff result color
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
      turnPopups.showPopup(feedbackText, feedbackColor);

      // Animate from Pile -> Loser
      cardAnimations.triggerCardAnimation(
        context: context,
        sourceId: SessionIds.pile,
        targetId: state.lastEventActorId!,
        count: state.lastEventCardCount,
      );
    }
  }

  void _handleShuffling(BuildContext context, SessionBlocState state) {
    HapticFeedback.lightImpact();
    // Check user setting for shuffle animation
    final shouldAnimate =
        di.sl.storageService.getBool('pref_shuffle_animation') ?? true;

    if (!shouldAnimate) return;

    // Clean distribution: Fly cards from pile directly to each player
    final participants = state.engineState.participants;
    if (participants.isEmpty) return;

    final totalCards = 52;
    final cardsPerPlayer = totalCards ~/ participants.length;

    // Distribute cards to all players simultaneously
    for (var participant in participants) {
      cardAnimations.triggerCardAnimation(
        context: context,
        sourceId: SessionIds.pile,
        targetId: participant.id,
        count: cardsPerPlayer,
      );
    }
  }

  void _handlePileDiscarded(BuildContext context, SessionBlocState state) {
    // Fly cards off-screen in random horizontal directions
    final rnd = math.Random();
    final size = MediaQuery.of(context).size;
    final pileOffset = cardAnimations.getCenterOffset(
      cardAnimations.pileKey,
      context,
    );

    if (pileOffset == Offset.zero) return;

    for (int i = 0; i < 12; i++) {
      final targetPoint = Offset(
        rnd.nextDouble() < 0.5 ? -150 : size.width + 150,
        rnd.nextDouble() * size.height,
      );
      Future.delayed(Duration(milliseconds: i * 40), () {
        if (!context.mounted) return;
        cardAnimations.triggerCardAnimation(
          context: context,
          sourceId: SessionIds.pile,
          targetId: SessionIds.offscreen,
          customStartOffset: pileOffset,
          customEndOffset: targetPoint,
        );
      });
    }
  }

  void _handleEmojiReceived(BuildContext context, SessionBlocState state) {
    final senderId = state.lastEventActorId;
    if (senderId != null) {
      final isMe = senderId == SessionIds.me;
      final sourceKey = isMe
          ? cardAnimations.avatarKeys[SessionIds.me]
          : cardAnimations.avatarKeys[senderId];

      if (sourceKey != null) {
        final emojiChar =
            state.chatMessages.lastWhere(
              (m) => m['type'] == 'emoji',
            )['emojiId'] ??
            '😊';
        final position = cardAnimations.getCenterOffset(sourceKey, context);
        final id = DateTime.now().microsecondsSinceEpoch.toString();

        setState(() {
          activeEmojis.add(
            FloatingEmoji(id: id, emoji: emojiChar, position: position),
          );
        });

        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            activeEmojis.removeWhere((e) => e.id == id);
          });
        });
      }
    }
  }
}
