import 'dart:async';
import 'dart:math';
import '../models/participant.dart';
import '../models/session_state.dart';
import '../models/unit.dart';
import '../models/session_enums.dart'; // New Import
import '../models/game_move.dart';
import 'game_session_handler.dart';

class LocalBotSessionHandler implements GameSessionHandler {
  // Streams
  final _stateController = StreamController<SessionState>.broadcast();
  final _eventController = StreamController<SessionEventType>.broadcast();

  @override
  Stream<SessionState> get sessionStateStream => _stateController.stream;

  @override
  Stream<SessionEventType> get eventStream => _eventController.stream;

  // Internal State
  SessionState _currentState = SessionState.initial();

  // -- Event State --
  String? _activeEventActorId;
  @override
  String? get activeEventActorId => _activeEventActorId;

  UnitRank? _lastRankClaimed;
  @override
  UnitRank? get lastRankClaimed => _lastRankClaimed;

  int _lastCountClaimed = 0;
  @override
  int get lastCountClaimed => _lastCountClaimed;

  final List<String> _gameLog = [];
  @override
  List<String> get gameLog => List.unmodifiable(_gameLog);

  String? _lastBluffWinnerId;
  @override
  String? get lastBluffWinnerId => _lastBluffWinnerId;

  String? _lastBluffLoserId;
  @override
  String? get lastBluffLoserId => _lastBluffLoserId;

  bool? _isBluffSuccessful;
  @override
  bool? get isBluffSuccessful => _isBluffSuccessful;

  GameMove? _lastMove;
  @override
  GameMove? get lastMove => _lastMove; // Now returns GameMove

  // -- Logic Internals --
  final List<Unit> _pile = [];
  final Map<String, List<Unit>> _hands = {};
  final Map<String, BotPersonality> _botPersonalities = {};
  UnitRank? _currentRank;
  String? _lastPlayedById;
  int _passCount = 0;
  int _botThinkingTimeS = 10;

  bool _isRevealingBluff = false;

  final Map<String, String> _pNames = {
    'me': 'You',
    'p1': 'Rahul',
    'p2': 'Priya',
    'p3': 'Amit',
    'p4': 'Soniya',
    'p5': 'Vikram',
    'p6': 'Anjali',
    'p7': 'Karan',
    'p8': 'Neha',
    'p9': 'Rohan',
  };

  Map<String, String> get pNames => Map.unmodifiable(_pNames);

  // Getter for UI state
  bool get isRevealingBluff => _isRevealingBluff;

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    _botThinkingTimeS = thinkingTimeS;
    _pile.clear();
    _lastMove = null;
    _currentRank = null;
    _lastPlayedById = null;
    _passCount = 0;
    _activeEventActorId = null;
    _lastRankClaimed = null;
    _lastCountClaimed = 0;
    _gameLog.clear();
    _lastBluffWinnerId = null;
    _lastBluffLoserId = null;
    _isBluffSuccessful = null;

    final actualPlayerCount = playerCount.clamp(2, 10);
    _addToLog("New game started with $actualPlayerCount players.");

    final deck = _generateDeck();
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
        name: pNames[id]!,
        unitCount: hands[id]!.length,
        isMe: id == 'me',
        isActive: id == 'me',
      );
    }).toList();

    _hands.clear();
    _botPersonalities.clear();

    final personalities = [
      BotPersonality.conservative,
      BotPersonality.aggressive,
      BotPersonality.balanced,
      BotPersonality.ghost,
      BotPersonality.balanced,
      BotPersonality.conservative,
      BotPersonality.aggressive,
      BotPersonality.balanced,
      BotPersonality.ghost,
    ];

    for (int i = 0; i < pIds.length; i++) {
      final id = pIds[i];
      _hands[id] = hands[id]!;
      if (id != 'me') {
        _botPersonalities[id] = personalities[(i - 1) % personalities.length];
      }
    }

    _currentState = SessionState(
      roomId: '101',
      participants: participants,
      myHand: _hands['me']!,
      currentPhase: SessionPhase.thinking,
      activeParticipantId: 'me',
      pileCount: 0,
      lastActionText: 'Game Started! Select cards and choose a rank.',
    );
    _emitState();
  }

  @override
  void playCards(List<String> unitIds, UnitRank declaredRank) {
    if (_currentState.activeParticipantId != 'me') return;

    // In local handler, we trust the ID list from the UI provider
    if (!_currentState.participants.any((p) => p.id == 'me' && p.isActive)) {
      return;
    }

    if (!_currentState.participants.first.isActive) return; // double check

    final unitsToPlay = _hands['me']!
        .where((u) => unitIds.contains(u.id))
        .toList();

    if (unitsToPlay.isEmpty) return;

    _executeMove('me', unitsToPlay, declaredRank);
  }

  @override
  void passTurn() {
    if (_currentState.activeParticipantId != 'me') return;
    _passCount++;
    _activeEventActorId = _currentState.activeParticipantId;
    _eventController.add(SessionEventType.passed);
    _addToLog("${pNames['me']} passed.");
    _advanceTurn();
  }

  @override
  void raiseChallenge() {
    if (_currentState.activeParticipantId != 'me' || _lastMove == null) return;

    final blufferId = _lastMove!.playerId;
    final challengerId = 'me';

    _activeEventActorId = challengerId;
    _isRevealingBluff = true;
    _eventController.add(SessionEventType.bluffCalled);
    _addToLog("${pNames[challengerId]} called bluff on ${pNames[blufferId]}!");

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (_isRevealingBluff) {
        _finalizeChallenge(blufferId, challengerId);
      }
    });
  }

  @override
  void sortHand() {
    final myCards = _hands['me'];
    if (myCards == null) return;
    myCards.sort((a, b) => a.rank.index.compareTo(b.rank.index));
    _currentState = _currentState.copyWith(myHand: List.from(myCards));
    _emitState();
  }

  @override
  void reorderHand(int oldIndex, int newIndex) {
    final myCards = _hands['me'];
    if (myCards == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = myCards.removeAt(oldIndex);
    myCards.insert(newIndex, item);

    _currentState = _currentState.copyWith(myHand: List.from(myCards));
    _emitState();
  }

  // Use dispose to close streams
  @override
  void dispose() {
    _stateController.close();
    _eventController.close();
  }

  // --- Private Helpers (Ported) ---

  void _emitState() {
    _stateController.add(_currentState);
  }

  List<Unit> _generateDeck() {
    final List<Unit> deck = [];
    int idCounter = 0;
    for (var suit in UnitType.values) {
      for (var rank in UnitRank.values) {
        deck.add(Unit(id: 'card_${idCounter++}', type: suit, rank: rank));
      }
    }
    return deck;
  }

  void _executeMove(String playerId, List<Unit> units, UnitRank declaredRank) {
    final oldPileCount = _currentState.pileCount;
    _pile.addAll(units);
    _lastPlayedById = playerId;
    _passCount = 0;
    _currentRank ??= declaredRank; // Set round rank if new

    _lastMove = GameMove(
      playerId: playerId,
      declaredRank: declaredRank,
      actualUnits: units,
    );

    _hands[playerId]!.removeWhere((u) => units.contains(u));

    // Phase 1: Update UI immediately (remove cards from hand, keep old pile count)
    List<Participant> updatedParticipants = _currentState.participants.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          unitCount: p.unitCount - units.length,
          isActive: false, // Turn ends
        );
      }
      return p;
    }).toList();

    _currentState = _currentState.copyWith(
      participants: updatedParticipants,
      myHand: playerId == 'me' ? _hands['me']! : _currentState.myHand,
      pileCount: oldPileCount, // Keep old count for now
      lastActionText: "${pNames[playerId]} played ${units.length} cards",
    );

    _activeEventActorId = playerId;
    _lastRankClaimed = declaredRank;
    _lastCountClaimed = units.length;
    _eventController.add(SessionEventType.cardsPlayed);
    _addToLog(
      "${pNames[playerId]} claimed ${units.length} ${declaredRank.name}s.",
    );
    _emitState();

    // Phase 2: Deferred update once cards reach the pile (approx 700ms)
    // We wait for the animation to finish before updating total and advancing turn
    Future.delayed(const Duration(milliseconds: 700), () {
      if (_currentState.currentPhase == SessionPhase.finished) return;

      _currentState = _currentState.copyWith(pileCount: _pile.length);
      _emitState();

      final winner = updatedParticipants.firstWhere((p) => p.id == playerId);
      if (winner.unitCount <= 0) {
        _currentState = _currentState.copyWith(
          lastActionText: "${pNames[playerId]} WINS!",
          currentPhase: SessionPhase.finished,
          winnerId: playerId,
        );
        _emitState();
        return;
      }

      // Final short delay before moving turn indicator, feels more natural
      Future.delayed(const Duration(milliseconds: 200), () {
        _advanceTurn();
      });
    });
  }

  void _advanceTurn() {
    final pIds = _currentState.participants.map((p) => p.id).toList();
    final currentIdx = pIds.indexOf(_currentState.activeParticipantId ?? 'me');
    final nextIdx = (currentIdx + 1) % pIds.length;
    final nextId = pIds[nextIdx];

    // Round End Check
    if (nextId == _lastPlayedById && _passCount >= pIds.length - 1) {
      _resetRoundState(nextId, wasDiscarded: true);
      _currentState = _currentState.copyWith(
        lastActionText:
            "Everyone passed! Pile discarded. ${pNames[nextId]} starts new round.",
      );
      _emitState();
      if (nextId != 'me') _scheduleBotTurn(nextId);
      return;
    }

    final updatedParticipants = _currentState.participants.map((p) {
      return p.copyWith(isActive: p.id == nextId);
    }).toList();

    _activeEventActorId = nextId;
    _eventController.add(SessionEventType.turnChanged);

    _currentState = _currentState.copyWith(
      participants: updatedParticipants,
      activeParticipantId: nextId,
    );
    _emitState();

    if (nextId != 'me') _scheduleBotTurn(nextId);
  }

  void _resetRoundState(
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
      _lastRankClaimed = null;
      _lastCountClaimed = 0;
      _eventController.add(SessionEventType.pileDiscarded);
      _addToLog("Everyone passed. Pile discarded.");
    } else {
      _activeEventActorId = winnerId;
      _eventController.add(SessionEventType.bluffResolved);
    }

    final updatedParticipants = _currentState.participants.map((p) {
      return p.copyWith(isActive: p.id == startId);
    }).toList();

    _currentState = _currentState.copyWith(
      participants: updatedParticipants,
      activeParticipantId: startId,
      pileCount: 0,
    );
  }

  void _finalizeChallenge(String blufferId, String challengerId) {
    _isRevealingBluff = false;
    final wasBluff = _checkIfBluff(_lastMove!);
    _isBluffSuccessful = wasBluff;

    // Emit resolved event
    _eventController.add(SessionEventType.bluffResolved);

    String resultText;
    String loserId;

    if (wasBluff) {
      resultText =
          "BLUFF CAUGHT! ${pNames[blufferId]} picks up ${_pile.length} cards.";
      loserId = blufferId;
    } else {
      resultText =
          "FALSE ALARM! ${pNames[challengerId]} picks up ${_pile.length} cards.";
      loserId = challengerId;
    }

    _distributePileTo(loserId);

    final winnerId = wasBluff ? challengerId : blufferId;
    final nextId = winnerId;

    _lastBluffWinnerId = winnerId;
    _lastBluffLoserId = loserId;

    _addToLog(
      wasBluff
          ? "Bluff caught! ${pNames[loserId]} takes the pile."
          : "Truth told! ${pNames[loserId]} takes the pile.",
    );

    _resetRoundState(nextId, wasDiscarded: false, winnerId: winnerId);

    _currentState = _currentState.copyWith(lastActionText: resultText);
    _emitState();

    if (nextId != 'me') {
      _scheduleBotTurn(nextId);
    }
  }

  void _distributePileTo(String playerId) {
    _hands[playerId]!.addAll(_pile);

    List<Participant> updatedParticipants = _currentState.participants.map((p) {
      if (p.id == playerId) {
        return p.copyWith(unitCount: _hands[playerId]!.length);
      }
      return p;
    }).toList();

    _currentState = _currentState.copyWith(
      participants: updatedParticipants,
      myHand: playerId == 'me' ? _hands['me']! : _currentState.myHand,
      pileCount: 0,
    );
    _pile.clear();
  }

  bool _checkIfBluff(GameMove move) {
    return move.actualUnits.any((u) => u.rank != move.declaredRank);
  }

  void _addToLog(String message) {
    _gameLog.insert(0, message);
    if (_gameLog.length > 20) _gameLog.removeLast();
    _emitState();
  }

  void _scheduleBotTurn(String botId) async {
    await Future.delayed(Duration(seconds: _botThinkingTimeS));

    // Check if game ended or phase changed while waiting
    if (_currentState.activeParticipantId != botId) return;

    final personality = _botPersonalities[botId] ?? BotPersonality.balanced;

    // 1. Challenge Logic
    if (_lastMove != null && _lastMove!.playerId != botId) {
      double challengeChance = 0.15;
      if (personality == BotPersonality.aggressive) challengeChance = 0.35;
      if (personality == BotPersonality.conservative) {
        challengeChance = _pile.length > 8 ? 0.25 : 0.05;
      }
      if (Random().nextDouble() < challengeChance) {
        // Bot challenges
        final blufferId = _lastMove!.playerId;
        _activeEventActorId = botId;
        _isRevealingBluff = true;
        _eventController.add(SessionEventType.bluffCalled);
        _addToLog("${pNames[botId]} called bluff on ${pNames[blufferId]}!");

        Future.delayed(const Duration(milliseconds: 2000), () {
          _finalizeChallenge(blufferId, botId);
        });
        return;
      }
    }

    // 2. Play/Pass Logic
    if (_currentRank == null) {
      if (_hands[botId]!.isNotEmpty) {
        _currentRank =
            _hands[botId]![Random().nextInt(_hands[botId]!.length)].rank;
      } else {
        _currentRank =
            UnitRank.values[Random().nextInt(UnitRank.values.length)];
      }
    } else {
      double passChance = 0.15;
      if (personality == BotPersonality.ghost) passChance = 0.45;
      if (personality == BotPersonality.conservative) passChance = 0.25;

      if (Random().nextDouble() < passChance) {
        _passCount++;
        _activeEventActorId = botId;
        _eventController.add(SessionEventType.passed);
        _addToLog("${pNames[botId]} passed.");
        _advanceTurn();
        return;
      }
    }

    final botHand = _hands[botId]!;
    if (botHand.isEmpty) return; // Should win before this

    final matchingCards = botHand.where((u) => u.rank == _currentRank).toList();
    List<Unit> botUnitsToPlay = [];

    // Simple AI selection (same as before)
    if (personality == BotPersonality.aggressive) {
      if (matchingCards.isNotEmpty && Random().nextDouble() > 0.2) {
        botUnitsToPlay = matchingCards.sublist(0, min(matchingCards.length, 4));
      } else {
        botUnitsToPlay = ([
          ...botHand,
        ]..shuffle()).sublist(0, min(botHand.length, 3));
      }
    } else if (personality == BotPersonality.conservative) {
      if (matchingCards.isNotEmpty) {
        botUnitsToPlay = [matchingCards.first];
      } else if (Random().nextDouble() < 0.1) {
        botUnitsToPlay = [botHand[Random().nextInt(botHand.length)]];
      } else {
        _passCount++;
        _activeEventActorId = botId;
        _eventController.add(SessionEventType.passed);
        _addToLog("${pNames[botId]} passed.");
        _advanceTurn();
        return;
      }
    } else {
      if (matchingCards.isNotEmpty && Random().nextDouble() > 0.4) {
        botUnitsToPlay = matchingCards.sublist(
          0,
          min(matchingCards.length, Random().nextInt(2) + 1),
        );
      } else {
        botUnitsToPlay = ([
          ...botHand,
        ]..shuffle()).sublist(0, min(botHand.length, Random().nextInt(2) + 1));
      }
    }

    if (botUnitsToPlay.isEmpty) {
      // Fallback pass
      _passCount++;
      _activeEventActorId = botId;
      _eventController.add(SessionEventType.passed);
      _addToLog("${pNames[botId]} passed.");
      _advanceTurn();
      return;
    }

    _executeMove(botId, botUnitsToPlay, _currentRank!);
  }
}
