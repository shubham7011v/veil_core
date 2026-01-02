import 'package:flutter/material.dart';
import 'dart:async';
import '../models/session_state.dart';
import '../models/unit.dart';
import '../models/session_enums.dart'; // New Enums
import '../models/game_move.dart';
import '../logic/game_session_handler.dart';
import '../logic/local_bot_session_handler.dart';

// Export for consumers
export '../models/session_enums.dart';

class SessionProvider extends ChangeNotifier {
  GameSessionHandler _handler;
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;

  SessionState _state = SessionState.initial();
  SessionState get state => _state;

  // -- Event State for Animations --
  SessionEventType _lastEvent = SessionEventType.none;
  SessionEventType get lastEvent => _lastEvent;
  String? _lastEventActorId;
  String? get lastEventActorId => _lastEventActorId;

  // -- UI Selection State --
  final List<String> _selectedUnitIds = [];
  List<String> get selectedUnitIds => List.unmodifiable(_selectedUnitIds);

  // -- Staging State --
  UnitRank? _stagedRank;
  UnitRank? get stagedRank => _stagedRank;
  bool _isSelectingRank = false;
  bool get isSelectingRank => _isSelectingRank;

  // -- Getters derived from Handler --
  UnitRank? get lastRankClaimed => _handler.lastRankClaimed;
  int get lastCountClaimed => _handler.lastCountClaimed;
  List<String> get gameLog => _handler.gameLog;
  String? get lastBluffWinnerId => _handler.lastBluffWinnerId;
  String? get lastBluffLoserId => _handler.lastBluffLoserId;
  bool? get isBluffSuccessful => _handler.isBluffSuccessful;
  GameMove? get lastMove => _handler.lastMove;

  // -- Missing Getters for UI compatibility --
  // Ideally these should be part of State or Handler interface.
  // For now, we delegate or default.

  // Logic usually tracks isRevealingBluff.
  // We need to add this to the GameSessionHandler interface if the UI needs it for state.
  // Or purely rely on events.
  // However, SessionScreen checks `provider.isRevealingBluff`.
  // Let's assume the handler handles the delay, but if we need UI feedback:
  bool get isRevealingBluff => (_handler is LocalBotSessionHandler)
      ? (_handler as LocalBotSessionHandler).isRevealingBluff
      : false; // Temporary cast until interface update

  // Helper for names.
  Map<String, String> get pNames {
    if (_handler is LocalBotSessionHandler) {
      return (_handler as LocalBotSessionHandler).pNames;
    }
    return {for (var p in state.participants) p.id: p.name};
  }

  String getPlayerName(String id) {
    return pNames[id] ?? id;
  }

  bool get isMyTurn => state.activeParticipantId == 'me';
  int get pileCount => state.pileCount;
  UnitRank? get currentRank =>
      _handler.lastMove?.declaredRank ??
      _stagedRank; // Approximation if needed, or we fetch from handler if we expose it
  // Note: currentRank in previous logic was complex, often tracking the round's declared rank.
  // We might want to expose round info from handler.
  // For now let's rely on move history or simple logic.
  // Wait, _currentRank was vital for round matching. We should probably expose it in handler or state.
  // Actually, let's keep it simple: UI mostly cares about "isRoundSet".
  bool get isRoundSet =>
      _handler.lastMove != null; // Simplification, strictly true if move made

  bool get shouldShowRankSelector =>
      isMyTurn && !isRoundSet && (_isSelectingRank || _stagedRank == null);

  SessionProvider({GameSessionHandler? handler})
    : _handler = handler ?? LocalBotSessionHandler() {
    _initHandler();
  }

  void _initHandler() {
    _stateSub?.cancel();
    _eventSub?.cancel();

    _stateSub = _handler.sessionStateStream.listen((newState) {
      _state = newState;
      notifyListeners();
    });

    _eventSub = _handler.eventStream.listen((event) {
      _lastEvent = event;
      _lastEventActorId = _handler.activeEventActorId;
      notifyListeners();
    });
  }

  void setHandler(GameSessionHandler newHandler) {
    _handler.dispose(); // Dispose old
    _handler = newHandler;
    _initHandler();
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    _handler.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PUBLIC ACTIONS (Forward to Handler)
  // ---------------------------------------------------------------------------

  void startSession({int playerCount = 5, int thinkingTimeS = 10}) {
    _handler.startGame(playerCount: playerCount, thinkingTimeS: thinkingTimeS);
  }

  void toggleRankSelectionMode() {
    if (!isMyTurn || isRoundSet) return;
    _isSelectingRank = !_isSelectingRank;
    notifyListeners();
  }

  void stageRank(UnitRank rank) {
    if (!isMyTurn || isRoundSet) return;
    _stagedRank = rank;
    _isSelectingRank = false;
    notifyListeners();
  }

  void toggleUnitSelection(String unitId) {
    if (_selectedUnitIds.contains(unitId)) {
      _selectedUnitIds.remove(unitId);
    } else {
      if (_selectedUnitIds.length >= 4) return;
      _selectedUnitIds.add(unitId);
    }
    notifyListeners();
  }

  bool canSubmit() {
    if (!isMyTurn) return false;
    if (_selectedUnitIds.isEmpty) return false;
    return isRoundSet || _stagedRank != null;
  }

  void submitSelectedUnits() {
    if (!canSubmit()) return;

    // Determine rank
    UnitRank rankToPlay;
    if (isRoundSet) {
      rankToPlay = _handler.lastMove!.declaredRank;
    } else {
      if (_stagedRank == null) return;
      rankToPlay = _stagedRank!;
      _stagedRank = null;
    }

    _handler.playCards(_selectedUnitIds, rankToPlay);
    _selectedUnitIds.clear();
  }

  void passTurn() {
    _handler.passTurn();
  }

  void raiseChallenge() {
    _handler.raiseChallenge();
  }
}
