import 'package:flutter/widgets.dart';
import 'websocket_handler_base.dart';
import '../../../domain/models/unit.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/constants/sound_assets.dart';
import '../../../../../core/services/audio/audio_service_interface.dart';

/// Mixin that handles game action methods for WebSocket handler.
/// Includes playing cards, passing, challenging, and hand management.
mixin WebSocketGameActionsMixin on WebSocketHandlerBase {
  // -- Game Action Methods --

  /// Start a new game
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    sendMessage({'type': 'START_GAME'});
  }

  /// Play selected cards with a declared rank
  void playCards(List<String> unitIds, UnitRank declaredRank) {
    sendMessage({
      'type': 'PLAY_CARDS',
      'data': {'cardIds': unitIds, 'declaredRank': declaredRank.name},
    });
    try {
      sl.audioService.playSfx(SoundAssets.cardSlide);
      sl.audioService.triggerHaptic(HapticType.light);
    } catch (e) {
      debugPrint('Audio/Haptic error (playCards): $e');
    }
  }

  /// Pass the current turn
  void passTurn() {
    sendMessage({'type': 'PASS'});
    try {
      sl.audioService.playSfx(SoundAssets.buttonTap);
      sl.audioService.triggerHaptic(HapticType.medium);
    } catch (e) {
      debugPrint('Audio/Haptic error (passTurn): $e');
    }
  }

  /// Raise a bluff challenge
  void raiseChallenge() {
    sendMessage({'type': 'CHALLENGE'});
    try {
      sl.audioService.playSfx(SoundAssets.buttonTap);
      sl.audioService.triggerHaptic(HapticType.heavy);
    } catch (e) {
      debugPrint('Audio/Haptic error (raiseChallenge): $e');
    }
  }

  /// Sort the hand locally by suit and rank
  void sortHand() {
    final sortedHand = List<Unit>.from(currentSessionState.myHand)
      ..sort((a, b) {
        if (a.type != b.type) {
          return a.type.index.compareTo(b.type.index);
        }
        return a.rank.index.compareTo(b.rank.index);
      });

    final newState = currentSessionState.copyWith(myHand: sortedHand);
    currentSessionState = newState;
    if (!stateStreamController.isClosed) {
      stateStreamController.add(newState);
    }
  }

  /// Reorder hand locally by dragging cards
  void reorderHand(int oldIndex, int newIndex) {
    final hand = List<Unit>.from(currentSessionState.myHand);
    final unit = hand.removeAt(oldIndex);
    hand.insert(newIndex, unit);

    final newState = currentSessionState.copyWith(myHand: hand);
    currentSessionState = newState;
    if (!stateStreamController.isClosed) {
      stateStreamController.add(newState);
    }
  }

  /// Leave the current room/game
  void leaveRoom(String roomCode) {
    sendMessage({'type': 'LEAVE_ROOM'});
  }
}
