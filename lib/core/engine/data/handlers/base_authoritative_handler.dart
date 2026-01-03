import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/participant.dart';
import '../../domain/models/session_state.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/session_enums.dart';
import '../../domain/models/game_move.dart';
import '../../domain/handlers/game_session_handler.dart';
import '../../domain/logic/game_rules.dart';

/// Base class for any handler that manages a local/authoritative game state.
/// This handles the "logic of the table" (pile, hands, turns, win conditions).
abstract class BaseAuthoritativeHandler implements GameSessionHandler {
  // Streams
  final _stateController = StreamController<SessionState>.broadcast();
  final _eventController = StreamController<SessionEventType>.broadcast();
  Timer? _turnTimer;
  int _currentTimerSeconds = 0;

  @override
  Stream<SessionState> get sessionStateStream => _stateController.stream;

  @override
  Stream<SessionEventType> get eventStream => _eventController.stream;

  // Internal State
  SessionState _currentState = SessionState.initial();
  SessionState get currentState => _currentState;

  // -- Table Data --
  final List<Unit> _pile = [];
  final Map<String, List<Unit>> _hands = {};
  UnitRank? _currentRank;
  String? _lastPlayedById;
  String? _potentialWinnerId;
  int _passCount = 0;
  bool _isRevealingBluff = false;
  GameMove? _lastMove;

  // -- Event Metadata --
  String? _activeEventActorId;
  UnitRank? _lastRankClaimed;
  int _lastCountClaimed = 0;
  final List<String> _gameLog = [];
  String? _lastBluffWinnerId;
  String? _lastBluffLoserId;
  bool? _isBluffSuccessful;

  @override
  String? get activeEventActorId => _activeEventActorId;
  @override
  UnitRank? get lastRankClaimed => _lastRankClaimed;
  @override
  int get lastCountClaimed => _lastCountClaimed;
  @override
  List<String> get gameLog => List.unmodifiable(_gameLog);
  @override
  String? get lastBluffWinnerId => _lastBluffWinnerId;
  @override
  String? get lastBluffLoserId => _lastBluffLoserId;
  @override
  bool? get isBluffSuccessful => _isBluffSuccessful;
  @override
  GameMove? get lastMove => _lastMove;
  @override
  bool get isRevealingBluff => _isRevealingBluff;

  // -- Protected Getters for Subclasses --
  @protected
  List<Unit> get pile => _pile;

  @protected
  Map<String, List<Unit>> get hands => _hands;

  @protected
  UnitRank? get currentRank => _currentRank;

  @protected
  int get passCount => _passCount;

  @protected
  String? get lastPlayedById => _lastPlayedById;

  @protected
  void setRoundRank(UnitRank rank) => _currentRank = rank;

  // Helper for subclasses to get a specific hand
  @protected
  List<Unit>? getHand(String playerId) => _hands[playerId];

  // Subclasses must provide names and handle "Turn Action" logic
  @override
  abstract final Map<String, String> pNames;

  /// Hook for subclasses to act when a participant becomes active (e.g. Bot thinking).
  void onTurnActive(String participantId);

  // --- Implementation of GameSessionHandler ---

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    _potentialWinnerId = null;
    _gameLog.clear();
    _pile.clear();
    _lastMove = null;
    _currentRank = null;
    _lastPlayedById = null;
    _passCount = 0;
    _activeEventActorId = null;
    _lastRankClaimed = null;
    _lastCountClaimed = 0;
    _lastBluffWinnerId = null;
    _lastBluffLoserId = null;
    _isBluffSuccessful = null;

    final actualPlayerCount = playerCount.clamp(2, 10);
    _addToLog("New game started with $actualPlayerCount players.");

    final deck = generateDeck();
    deck.shuffle();

    final allPIds = [
      'me',
      'p1',
      'p2',
      'p3',
      'p4',
      'p5',
      'p6',
      'p7',
      'p8',
      'p9',
    ];
    final pIds = allPIds.sublist(0, actualPlayerCount);

    final hands = <String, List<Unit>>{for (var id in pIds) id: []};
    for (int i = 0; i < deck.length; i++) {
      final pid = pIds[i % actualPlayerCount];
      hands[pid]!.add(deck[i]);
    }

    final participants = pIds.map((id) {
      return Participant(
        id: id,
        name: pNames[id] ?? id,
        unitCount: hands[id]!.length,
        isMe: id == 'me',
        isActive: id == 'me',
      );
    }).toList();

    _hands.clear();
    for (var id in pIds) {
      _hands[id] = hands[id]!;
    }

    // Phase 1: Shuffling
    _currentState = SessionState(
      roomId: '101',
      participants: participants.map((p) => p.copyWith(unitCount: 0)).toList(),
      myHand: [],
      currentPhase: SessionPhase.thinking,
      activeParticipantId: 'me',
      pileCount: deck.length, // START WITH FULL DECK
      lastActionText: 'Shuffling deck...',
    );
    emitState();

    // Phase 1.5: Shuffling (delayed slightly to ensure UI is ready)
    Future.delayed(const Duration(milliseconds: 500), () {
      _eventController.add(SessionEventType.shuffling);
    });

    // Phase 2: Update state after shuffle completes (no separate deal event)
    Future.delayed(const Duration(milliseconds: 1800), () {
      _currentState = _currentState.copyWith(
        participants: participants,
        myHand: _hands['me']!,
        pileCount: 0, // PILE GOES TO 0 AFTER DEALING
        lastActionText: 'Game Started! Select a rank to begin.',
      );
      emitState();
      startTurnTimer();
    });
  }

  @override
  void playCards(List<String> unitIds, UnitRank declaredRank) {
    if (_currentState.activeParticipantId != 'me') return;
    final myCards = _hands['me']!;
    final unitsToPlay = myCards.where((u) => unitIds.contains(u.id)).toList();
    if (unitsToPlay.isEmpty) return;
    executeMove('me', unitsToPlay, declaredRank);
  }

  @override
  void passTurn() {
    final activeId = _currentState.activeParticipantId;
    if (activeId == null) return;
    _passCount++;
    _activeEventActorId = activeId;
    _eventController.add(SessionEventType.passed);
    _addToLog("${pNames[activeId] ?? activeId} passed.");
    stopTurnTimer();
    advanceTurn();
  }

  @override
  void raiseChallenge() {
    final challengerId = _currentState.activeParticipantId;
    if (challengerId == null ||
        !GameRules.canParticipantCallBluff(
          challengerId,
          challengerId,
          _lastMove,
        )) {
      return;
    }

    final blufferId = _lastMove!.playerId;
    _activeEventActorId = challengerId;
    _isRevealingBluff = true;
    _eventController.add(SessionEventType.bluffCalled);
    _addToLog(
      "${pNames[challengerId] ?? challengerId} called bluff on ${pNames[blufferId] ?? blufferId}!",
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (_isRevealingBluff) {
        finalizeChallenge(blufferId, challengerId);
      }
    });
  }

  @override
  void sortHand() {
    final myCards = _hands['me'];
    if (myCards == null) return;
    myCards.sort((a, b) => a.rank.index.compareTo(b.rank.index));
    _currentState = _currentState.copyWith(myHand: List.from(myCards));
    emitState();
  }

  @override
  void reorderHand(int oldIndex, int newIndex) {
    // We treat the indices as absolute to the hand for now.
    // However, if the UI passes relative indices, we should fix that in the BLoC/UI.
    final myCards = _hands['me'];
    if (myCards == null) return;

    if (oldIndex < 0 || oldIndex >= myCards.length) return;

    // Correcting newIndex for removeAt logic
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    newIndex = newIndex.clamp(0, myCards.length - 1);

    final item = myCards.removeAt(oldIndex);
    myCards.insert(newIndex, item);

    _currentState = _currentState.copyWith(myHand: List.from(myCards));
    emitState();
  }

  @override
  void dispose() {
    stopTurnTimer();
    _stateController.close();
    _eventController.close();
  }

  // --- Protected Methods for Subclasses ---

  void emitState() {
    _stateController.add(_currentState);
  }

  void startTurnTimer() {
    stopTurnTimer();
    _currentTimerSeconds = (_currentRank == null)
        ? GameRules.firstTurnLimitS
        : GameRules.standardTurnLimitS;
    _currentState = _currentState.copyWith(turnTimerS: _currentTimerSeconds);
    emitState();

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTimerSeconds > 0) {
        _currentTimerSeconds--;
        _currentState = _currentState.copyWith(
          turnTimerS: _currentTimerSeconds,
        );
        emitState();
      } else {
        stopTurnTimer();
        passTurn(); // Auto-pass on timeout
      }
    });
  }

  void stopTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    _currentState = _currentState.copyWith(clearTimer: true);
    emitState();
  }

  List<Unit> generateDeck() {
    final List<Unit> deck = [];
    int idCounter = 0;
    for (var suit in UnitType.values) {
      for (var rank in UnitRank.values) {
        deck.add(Unit(id: 'card_${idCounter++}', type: suit, rank: rank));
      }
    }
    return deck;
  }

  void executeMove(String playerId, List<Unit> units, UnitRank declaredRank) {
    final oldPileCount = _currentState.pileCount;
    _pile.addAll(units);
    _lastPlayedById = playerId;
    _passCount = 0;
    _currentRank ??= declaredRank;

    _lastMove = GameMove(
      playerId: playerId,
      declaredRank: declaredRank,
      actualUnits: units,
    );

    // Check if the potential winner should win because someone just played
    if (_potentialWinnerId != null && _potentialWinnerId != playerId) {
      final winnerId = _potentialWinnerId!;
      if (GameRules.hasPlayerWon(
        playerId: winnerId,
        potentialWinnerId: winnerId,
        passCount: _passCount,
        participantCount: _currentState.participants.length,
        isNextPlayerStartingRound: true,
      )) {
        _currentState = _currentState.copyWith(
          lastActionText: "${pNames[winnerId] ?? winnerId} WINS!",
          currentPhase: SessionPhase.finished,
          winnerId: winnerId,
        );
        emitState();
        return;
      }
    }

    _hands[playerId]!.removeWhere((u) => units.contains(u));
    if (_hands[playerId]!.isEmpty) _potentialWinnerId = playerId;

    _currentState = _currentState.copyWith(
      participants: _currentState.participants
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    unitCount: p.unitCount - units.length,
                    isActive: false,
                  )
                : p,
          )
          .toList(),
      myHand: playerId == 'me' ? _hands['me']! : _currentState.myHand,
      pileCount: oldPileCount,
      lastActionText:
          "${pNames[playerId] ?? playerId} played ${units.length} cards",
    );

    _activeEventActorId = playerId;
    _lastRankClaimed = declaredRank;
    _lastCountClaimed = units.length;
    _eventController.add(SessionEventType.cardsPlayed);
    _addToLog(
      "${pNames[playerId] ?? playerId} claimed ${units.length} ${declaredRank.name}s.",
    );
    stopTurnTimer();
    emitState();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (_currentState.currentPhase == SessionPhase.finished) return;
      _currentState = _currentState.copyWith(pileCount: _pile.length);
      emitState();
      advanceTurn();
    });
  }

  void advanceTurn() {
    final nextId = GameRules.getNextParticipantId(
      _currentState.activeParticipantId ?? 'me',
      _currentState.participants,
    );

    if (nextId == _lastPlayedById &&
        _passCount >= _currentState.participants.length - 1) {
      if (GameRules.hasPlayerWon(
        playerId: nextId,
        potentialWinnerId: _potentialWinnerId,
        passCount: _passCount,
        participantCount: _currentState.participants.length,
        isNextPlayerStartingRound: false,
      )) {
        _currentState = _currentState.copyWith(
          lastActionText: "${pNames[nextId] ?? nextId} WINS!",
          currentPhase: SessionPhase.finished,
          winnerId: nextId,
        );
        emitState();
        return;
      }
      resetRoundState(nextId, wasDiscarded: true);
      return;
    }

    _currentState = _currentState.copyWith(
      participants: _currentState.participants
          .map((p) => p.copyWith(isActive: p.id == nextId))
          .toList(),
      activeParticipantId: nextId,
    );
    _activeEventActorId = nextId;
    _eventController.add(SessionEventType.turnChanged);
    emitState();
    startTurnTimer();
    onTurnActive(nextId);
  }

  void resetRoundState(
    String startId, {
    required bool wasDiscarded,
    String? winnerId,
  }) {
    _currentRank = null;
    _lastMove = null;
    _lastPlayedById = null;
    _passCount = 0;
    _pile.clear();

    if (wasDiscarded) {
      _activeEventActorId = startId;
      _eventController.add(SessionEventType.pileDiscarded);
      _addToLog("Everyone passed. Pile discarded.");
    }

    _currentState = _currentState.copyWith(
      participants: _currentState.participants
          .map((p) => p.copyWith(isActive: p.id == startId))
          .toList(),
      activeParticipantId: startId,
      pileCount: 0,
    );
    emitState();
    startTurnTimer();
    onTurnActive(startId);
  }

  void finalizeChallenge(String blufferId, String challengerId) {
    _isRevealingBluff = false;
    final wasBluff = GameRules.isBluff(_lastMove!);
    final loserId = GameRules.getBluffLoserId(
      wasBluff: wasBluff,
      blufferId: blufferId,
      challengerId: challengerId,
    );

    _lastBluffWinnerId = wasBluff ? challengerId : blufferId;
    _lastBluffLoserId = loserId;
    _isBluffSuccessful = wasBluff;

    // Only check bluffer win if they WEREN'T bluffing
    if (!wasBluff &&
        GameRules.hasPlayerWon(
          playerId: blufferId,
          potentialWinnerId: _potentialWinnerId,
          passCount: 0,
          participantCount: 1,
          isNextPlayerStartingRound: true,
        )) {
      _currentState = _currentState.copyWith(
        lastActionText: "${pNames[blufferId] ?? blufferId} WINS!",
        currentPhase: SessionPhase.finished,
        winnerId: blufferId,
      );
      emitState();
      return;
    }

    if (!wasBluff &&
        _potentialWinnerId != null &&
        _potentialWinnerId != blufferId) {
      _currentState = _currentState.copyWith(
        lastActionText:
            "${pNames[_potentialWinnerId] ?? _potentialWinnerId} WINS!",
        currentPhase: SessionPhase.finished,
        winnerId: _potentialWinnerId,
      );
      emitState();
      return;
    }

    if (GameRules.shouldResetWinProgress(loserId, _potentialWinnerId ?? "")) {
      _potentialWinnerId = null;
    }

    final resultText = wasBluff
        ? "BLUFF CAUGHT! ${pNames[blufferId] ?? blufferId} picks up ${_pile.length} cards."
        : "FALSE ALARM! ${pNames[challengerId] ?? challengerId} picks up ${_pile.length} cards.";
    final winnerId = wasBluff ? challengerId : blufferId;

    // Note: distributePileTo will handle emitting the event and setting actor/count
    Future.delayed(const Duration(milliseconds: 1000), () {
      distributePileTo(loserId);
      resetRoundState(winnerId, wasDiscarded: false, winnerId: winnerId);
      _currentState = _currentState.copyWith(lastActionText: resultText);
      emitState();
    });
  }

  void distributePileTo(String playerId) {
    _activeEventActorId = playerId;
    _lastCountClaimed = _pile.length;
    _eventController.add(SessionEventType.cardsPickedUp);
    _hands[playerId]!.addAll(_pile);
    _pile.clear();

    _currentState = _currentState.copyWith(
      participants: _currentState.participants
          .map(
            (p) => p.id == playerId
                ? p.copyWith(unitCount: _hands[playerId]!.length)
                : p,
          )
          .toList(),
      myHand: playerId == 'me' ? _hands['me']! : _currentState.myHand,
      pileCount: 0,
    );
  }

  void _addToLog(String message) {
    _gameLog.insert(0, message);
    if (_gameLog.length > 20) _gameLog.removeLast();
    emitState();
  }
}
