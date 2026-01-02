import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../models/participant.dart';
import '../models/session_state.dart';
import '../models/unit.dart';

enum BotPersonality { conservative, aggressive, balanced, ghost }

class SessionProvider extends ChangeNotifier {
  SessionState _state = SessionState.initial();
  SessionState get state => _state;

  // -- UI Selection State --
  final List<String> _selectedUnitIds = [];
  List<String> get selectedUnitIds => List.unmodifiable(_selectedUnitIds);

  // -- Game Logic State --
  final List<Unit> _pile = [];
  _GameMove? _lastMove;

  UnitRank? _currentRank;
  UnitRank? get currentRank => _currentRank;

  // For the first player of a round to "preview" or "stage" their rank choice
  UnitRank? _stagedRank;
  UnitRank? get stagedRank => _stagedRank;

  bool get isRoundSet => _currentRank != null;
  bool _isSelectingRank = false;
  bool get isSelectingRank => _isSelectingRank;

  bool get shouldShowRankSelector =>
      isMyTurn && !isRoundSet && (_isSelectingRank || _stagedRank == null);

  // -- Getters --
  bool get isMyTurn => state.activeParticipantId == 'me';
  int get pileCount => _pile.length;

  // -- Game Logic Internals --
  final Map<String, List<Unit>> _hands = {};
  final Map<String, BotPersonality> _botPersonalities = {};
  String? _lastPlayedById;
  int _passCount = 0;
  int _botThinkingTimeS = 10; // Default 10s

  // Names map for bots
  final Map<String, String> pNames = {
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

  SessionProvider() {
    _startNewGame(5); // Initial default
  }

  // ---------------------------------------------------------------------------
  // GAME INITIALIZATION
  // ---------------------------------------------------------------------------

  void _startNewGame(int playerCount) {
    _pile.clear();
    _lastMove = null;
    _currentRank = null;
    _stagedRank = null;
    _isSelectingRank = false;
    _selectedUnitIds.clear();
    _lastPlayedById = null;
    _passCount = 0;

    final deck = _generateDeck();
    deck.shuffle();

    // Support 2 to 10 players
    final actualPlayerCount = playerCount.clamp(2, 10);
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

    // Assign Personalities
    final personalities = [
      BotPersonality.conservative, // p1: Rahul
      BotPersonality.aggressive, // p2: Priya
      BotPersonality.balanced, // p3: Amit
      BotPersonality.ghost, // p4: Soniya
      BotPersonality.balanced, // p5
      BotPersonality.conservative, // p6
      BotPersonality.aggressive, // p7
      BotPersonality.balanced, // p8
      BotPersonality.ghost, // p9
    ];

    for (int i = 0; i < pIds.length; i++) {
      final id = pIds[i];
      _hands[id] = hands[id]!;
      if (id != 'me') {
        _botPersonalities[id] = personalities[(i - 1) % personalities.length];
      }
    }

    _state = _state.copyWith(
      roomId: '101',
      participants: participants,
      myHand: _hands['me']!,
      currentPhase: SessionPhase.thinking,
      activeParticipantId: 'me',
      pileCount: 0,
      lastActionText: 'Game Started! Select cards and choose a rank.',
    );
    notifyListeners();
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

  // ---------------------------------------------------------------------------
  // PLAYER ACTIONS
  // ---------------------------------------------------------------------------

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
    // Selection is complete if round is already set OR if user has staged a rank
    return isRoundSet || _stagedRank != null;
  }

  void submitSelectedUnits() {
    if (!canSubmit()) return;

    // If it's a new round, finalize the staged rank
    if (!isRoundSet && _stagedRank != null) {
      _currentRank = _stagedRank;
      _stagedRank = null;
    }

    final unitsToPlay = _state.myHand
        .where((u) => _selectedUnitIds.contains(u.id))
        .toList();
    _executeMove('me', unitsToPlay, _currentRank!);
    _selectedUnitIds.clear();
  }

  void passTurn() {
    if (!isMyTurn) return;
    _passCount++;
    _advanceTurn();
  }

  void startSession({int playerCount = 5, int thinkingTimeS = 10}) {
    _botThinkingTimeS = thinkingTimeS;
    _startNewGame(playerCount);
  }

  void raiseChallenge() {
    if (!isMyTurn || _lastMove == null) return;

    final wasBluff = _checkIfBluff(_lastMove!);
    final blufferId = _lastMove!.playerId;
    final challengerId = state.activeParticipantId!;

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

    // After Bluff Resolution: Round Resets
    _currentRank = null;
    _lastMove = null;
    _stagedRank = null;
    _lastPlayedById = null;
    _passCount = 0;

    // Next turn goes to the winner of the challenge
    final winnerId = wasBluff ? challengerId : blufferId;
    final nextId = winnerId;

    final updatedParticipants = _state.participants.map((p) {
      return p.copyWith(isActive: p.id == nextId);
    }).toList();

    _state = _state.copyWith(
      lastActionText: resultText,
      activeParticipantId: nextId,
      participants: updatedParticipants,
      pileCount: 0,
    );
    notifyListeners();

    if (nextId != 'me') {
      _scheduleBotTurn(nextId);
    }
  }

  // ---------------------------------------------------------------------------
  // GAME ENGINE
  // ---------------------------------------------------------------------------

  void _executeMove(String playerId, List<Unit> units, UnitRank declaredRank) {
    _pile.addAll(units);
    _lastPlayedById = playerId;
    _passCount = 0;

    _lastMove = _GameMove(
      playerId: playerId,
      declaredRank: declaredRank,
      actualUnits: units,
    );

    // Remove cards from player's hand
    _hands[playerId]!.removeWhere((u) => units.contains(u));

    if (playerId == 'me') {
      _state = _state.copyWith(myHand: _hands['me']!);
    }

    final updatedParticipants = _state.participants.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          unitCount: p.unitCount - units.length,
          isActive: false,
        );
      }
      return p;
    }).toList();

    _state = _state.copyWith(
      participants: updatedParticipants,
      pileCount: _pile.length,
      lastActionText: "${pNames[playerId]} played ${units.length} cards",
    );

    // Win Condition
    if (updatedParticipants.firstWhere((p) => p.id == playerId).unitCount <=
        0) {
      _state = _state.copyWith(
        lastActionText: "${pNames[playerId]} WINS!",
        currentPhase: SessionPhase.finished,
        winnerId: playerId,
      );
      notifyListeners();
      return;
    }

    _advanceTurn();
  }

  void _advanceTurn() {
    final pIds = _state.participants.map((p) => p.id).toList();
    final currentIdx = pIds.indexOf(_state.activeParticipantId ?? 'me');
    final nextIdx = (currentIdx + 1) % pIds.length;
    final nextId = pIds[nextIdx];

    // PASS-CYCLE END RULE
    // If turn comes back to the player who last played and everyone passed
    if (nextId == _lastPlayedById && _passCount >= pIds.length - 1) {
      _pile.clear();
      _currentRank = null;
      _lastMove = null;
      _stagedRank = null;
      _lastPlayedById = null;
      _passCount = 0;

      final updatedParticipants = _state.participants.map((p) {
        return p.copyWith(isActive: p.id == nextId);
      }).toList();

      _state = _state.copyWith(
        participants: updatedParticipants,
        activeParticipantId: nextId,
        pileCount: 0,
        lastActionText:
            "Everyone passed! Pile discarded. ${pNames[nextId]} starts new round.",
      );
      notifyListeners();

      if (nextId != 'me') {
        _scheduleBotTurn(nextId);
      }
      return;
    }

    final updatedParticipants = _state.participants.map((p) {
      return p.copyWith(isActive: p.id == nextId);
    }).toList();

    _state = _state.copyWith(
      participants: updatedParticipants,
      activeParticipantId: nextId,
    );
    notifyListeners();

    if (nextId != 'me') {
      _scheduleBotTurn(nextId);
    }
  }

  void _distributePileTo(String playerId) {
    _hands[playerId]!.addAll(_pile);

    if (playerId == 'me') {
      _state = _state.copyWith(myHand: _hands['me']!);
    }

    final updatedParticipants = _state.participants.map((p) {
      if (p.id == playerId) {
        return p.copyWith(unitCount: _hands[playerId]!.length);
      }
      return p;
    }).toList();

    _state = _state.copyWith(participants: updatedParticipants, pileCount: 0);

    _pile.clear();
  }

  bool _checkIfBluff(_GameMove move) {
    return move.actualUnits.any((u) => u.rank != move.declaredRank);
  }

  // ---------------------------------------------------------------------------
  // BOT AI
  // ---------------------------------------------------------------------------

  void _scheduleBotTurn(String botId) async {
    await Future.delayed(Duration(seconds: _botThinkingTimeS));
    final personality = _botPersonalities[botId] ?? BotPersonality.balanced;

    // 1. Chance to Challenge
    if (_lastMove != null && _lastMove!.playerId != botId) {
      double challengeChance = 0.15;
      if (personality == BotPersonality.aggressive) challengeChance = 0.35;
      if (personality == BotPersonality.conservative) {
        challengeChance = _pile.length > 8 ? 0.25 : 0.05;
      }

      if (Random().nextDouble() < challengeChance) {
        raiseChallenge();
        return;
      }
    }

    // 2. Play Decisions
    if (_currentRank == null) {
      // Starting a new round: pick a rank the bot actually has if possible
      if (_hands[botId]!.isNotEmpty) {
        _currentRank =
            _hands[botId]![Random().nextInt(_hands[botId]!.length)].rank;
      } else {
        _currentRank =
            UnitRank.values[Random().nextInt(UnitRank.values.length)];
      }
    } else {
      // Bot chance to pass
      double passChance = 0.15;
      if (personality == BotPersonality.ghost) passChance = 0.45;
      if (personality == BotPersonality.conservative) passChance = 0.25;

      if (Random().nextDouble() < passChance) {
        _passCount++;
        _advanceTurn();
        return;
      }
    }

    final botHand = _hands[botId]!;
    if (botHand.isEmpty) return;

    final matchingCards = botHand.where((u) => u.rank == _currentRank).toList();
    List<Unit> botUnitsToPlay = [];

    // Personality Based Play
    if (personality == BotPersonality.aggressive) {
      // Aggressive: Play many if matching, or bluff big
      if (matchingCards.isNotEmpty && Random().nextDouble() > 0.2) {
        final count = min(matchingCards.length, 4);
        botUnitsToPlay = matchingCards.sublist(0, count);
      } else {
        // Bluff big
        final count = min(botHand.length, 3);
        final shuffledHand = [...botHand]..shuffle();
        botUnitsToPlay = shuffledHand.sublist(0, count);
      }
    } else if (personality == BotPersonality.conservative) {
      // Conservative: Play 1 if matching, rarely bluff
      if (matchingCards.isNotEmpty) {
        botUnitsToPlay = [matchingCards.first];
      } else if (Random().nextDouble() < 0.1) {
        // Very rare bluff
        botUnitsToPlay = [botHand[Random().nextInt(botHand.length)]];
      } else {
        // Just pass instead of bluffing if unsure
        _passCount++;
        _advanceTurn();
        return;
      }
    } else {
      // Balanced / Ghost
      if (matchingCards.isNotEmpty && Random().nextDouble() > 0.4) {
        final count = min(matchingCards.length, Random().nextInt(2) + 1);
        botUnitsToPlay = matchingCards.sublist(0, count);
      } else {
        // Bluff moderate
        final count = min(botHand.length, Random().nextInt(2) + 1);
        final shuffledHand = [...botHand]..shuffle();
        botUnitsToPlay = shuffledHand.sublist(0, count);
      }
    }

    if (botUnitsToPlay.isEmpty) {
      _passCount++;
      _advanceTurn();
      return;
    }

    _executeMove(botId, botUnitsToPlay, _currentRank!);
  }
}

class _GameMove {
  final String playerId;
  final UnitRank declaredRank;
  final List<Unit> actualUnits;

  _GameMove({
    required this.playerId,
    required this.declaredRank,
    required this.actualUnits,
  });
}
