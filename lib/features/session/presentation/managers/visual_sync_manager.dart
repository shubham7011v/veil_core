import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../bloc/session_state.dart';

/// Manages syncing the visual state of the game (e.g. active player highlights)
/// with event animations to prevent premature UI updates.
class VisualSyncManager {
  final void Function(VoidCallback fn) setState;

  String? _visualActivePlayerId;
  int _lastHandledEventTimestamp = 0;
  Timer? _visualUpdateTimer;
  bool _isShuffling = false;

  VisualSyncManager({required this.setState});

  String? get visualActivePlayerId => _visualActivePlayerId;
  int get lastHandledEventTimestamp => _lastHandledEventTimestamp;
  bool get isShuffling => _isShuffling;

  /// Initialize with starting state
  void initialize(SessionBlocState state) {
    _visualActivePlayerId ??= state.engineState.activeParticipantId;
  }

  /// Start or stop shuffling mask
  void setShuffling(bool value) {
    setState(() {
      _isShuffling = value;
    });
  }

  /// Should the event be handled (prevents duplicates)
  bool shouldHandleEvent(int timestamp) {
    if (timestamp != 0 && timestamp != _lastHandledEventTimestamp) {
      _lastHandledEventTimestamp = timestamp;
      return true;
    }
    return false;
  }

  /// Update the visual active player state, potentially with a delay
  void updateVisualActivePlayer(SessionBlocState state, {bool mounted = true}) {
    _visualUpdateTimer?.cancel();

    if (state.lastEvent == engine.SessionEventType.cardsPlayed) {
      // Delay update to wait for card flying animations (~1s)
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
  }

  /// Create a masked state for UI rendering that uses the visual active ID
  SessionBlocState getVisualState(SessionBlocState state) {
    var engineState = state.engineState;

    // Mask hand during shuffling to prevent jumping
    if (_isShuffling) {
      engineState = engineState.copyWith(myHand: const []);
    }

    return state.copyWith(
      engineState: engineState.copyWith(
        activeParticipantId:
            _visualActivePlayerId ?? state.engineState.activeParticipantId,
      ),
    );
  }

  void dispose() {
    _visualUpdateTimer?.cancel();
  }
}
