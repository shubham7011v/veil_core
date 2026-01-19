import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import '../widgets/flying_cards_layer.dart';
import '../utils/session_constants.dart';
import '../bloc/session_state.dart';

/// Manages card flying animations between positions on the screen
/// Extracted from session_screen.dart to improve separation of concerns
class CardAnimationManager {
  final void Function(VoidCallback fn) setState;

  final Map<String, GlobalKey> _avatarKeys = {SessionIds.me: GlobalKey()};
  final GlobalKey _pileKey = GlobalKey();
  final GlobalKey _stagingKey = GlobalKey();
  final List<FlyingCard> _flyingCards = [];

  CardAnimationManager({required this.setState});

  // Getters for keys (used by widgets)
  Map<String, GlobalKey> get avatarKeys => _avatarKeys;
  GlobalKey get pileKey => _pileKey;
  GlobalKey get stagingKey => _stagingKey;
  List<FlyingCard> get flyingCards => _flyingCards;

  /// Update avatar keys based on current participant list
  void updateAvatarKeys(SessionBlocState state) {
    // Keep track of which IDs we've already assigned a key to in this pass
    // to avoid mapping multiple IDs (e.g. p.id and p.sessionId) inconsistently
    final processedIds = <String>{};

    for (var p in state.engineState.participants) {
      if (p.isMe) {
        // Map my actual ID to the SessionIds.me key used by HandView
        final oldKey = _avatarKeys[p.id];
        _avatarKeys[p.id] = _avatarKeys[SessionIds.me]!;
        processedIds.add(p.id);

        if (oldKey != _avatarKeys[p.id]) {
          AppLogger.info('Mapped "me" ID ${p.id} to shared me key');
        }

        // Also map sessionId to the same key
        if (p.sessionId != null) {
          _avatarKeys[p.sessionId!] = _avatarKeys[SessionIds.me]!;
          processedIds.add(p.sessionId!);
        }
      } else {
        // If we don't have a key for this participant ID,
        // OR if it's currently pointing to the "me" key (stale mapping),
        // create a new unique key.
        final currentKey = _avatarKeys[p.id];
        if (currentKey == null || currentKey == _avatarKeys[SessionIds.me]) {
          _avatarKeys[p.id] = GlobalKey(debugLabel: 'avatar_${p.id}');
          AppLogger.info(
            'Assigned NEW unique key to opponent ${p.id} (was ${currentKey == null ? "null" : "stale me key"})',
          );
        }
        processedIds.add(p.id);

        // Map sessionId to the same key so we can find them by either ID
        if (p.sessionId != null) {
          _avatarKeys[p.sessionId!] = _avatarKeys[p.id]!;
          processedIds.add(p.sessionId!);
        }
      }
    }

    // Optional: Clean up keys for participants no longer in the session
    // This helps avoid lingering GlobalKeys in the tree
    // _avatarKeys.removeWhere((id, _) => id != SessionIds.me && !processedIds.contains(id));
  }

  /// Get the center offset of a widget by its GlobalKey (PUBLIC for use by GameEventHandler)
  Offset getCenterOffset(GlobalKey key, BuildContext context) {
    if (key.currentContext == null) return Offset.zero;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    return Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  }

  /// Trigger a card flying animation from source to target
  void triggerCardAnimation({
    required BuildContext context,
    required String sourceId,
    required String targetId,
    int count = 1,
    int retryCount = 0,
    bool randomOffset = false,
    Offset? customStartOffset,
    Offset? customEndOffset,
    VoidCallback? onComplete,
  }) {
    // DEBUG LOG: Check entry count
    AppLogger.info(
      '[DEBUG] triggerCardAnimation CALLED: $sourceId -> $targetId (retry: $retryCount)',
    );

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

    final screenSize = MediaQuery.of(context).size;

    // Use addPostFrameCallback to ensure keys are rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // DEBUG LOG: Check callback execution
      AppLogger.info(
        '[DEBUG] PostFrameCallback RUNNING for: $sourceId -> $targetId',
      );

      Offset start =
          customStartOffset ??
          (sourceKey != null
              ? getCenterOffset(sourceKey, context)
              : Offset.zero);

      Offset end =
          customEndOffset ??
          (targetKey != null
              ? getCenterOffset(targetKey, context)
              : Offset.zero);

      // Final fallback logic: only apply if we've exhausted retries or don't have a key to find
      if (retryCount >= 20 ||
          (sourceKey == null && customStartOffset == null)) {
        if (start == Offset.zero) {
          if (sourceId == SessionIds.pile) {
            start = Offset(screenSize.width / 2, screenSize.height / 2);
          } else if (sourceId == SessionIds.staging) {
            start = Offset(screenSize.width / 2, screenSize.height - 100);
          } else {
            start = Offset(screenSize.width / 2, 80);
          }
        }
      }

      if (retryCount >= 20 || (targetKey == null && customEndOffset == null)) {
        if (end == Offset.zero) {
          if (targetId == SessionIds.pile) {
            end = Offset(screenSize.width / 2, screenSize.height / 2);
          } else if (targetId == SessionIds.staging) {
            end = Offset(screenSize.width / 2, screenSize.height - 100);
          } else {
            end = Offset(screenSize.width / 2, 80);
          }
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
            if (!context.mounted) return;
            triggerCardAnimation(
              context: context,
              sourceId: sourceId,
              targetId: targetId,
              count: count,
              retryCount: retryCount + 1,
              randomOffset: randomOffset,
              customStartOffset: customStartOffset,
              customEndOffset: customEndOffset,
              onComplete: onComplete,
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
        setState(() {
          _flyingCards.removeWhere((anim) => anim.id == id);
        });
        onComplete?.call();
      });
    });
  }

  /// Clean up resources
  void dispose() {
    _flyingCards.clear();
    _avatarKeys.removeWhere((key, _) => key != SessionIds.me);
  }
}
