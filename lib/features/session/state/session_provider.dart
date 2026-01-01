import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../models/participant.dart';
import '../models/session_state.dart';
import '../models/unit.dart';

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

  // -- Getters --
  bool get isMyTurn => state.activeParticipantId == 'me';
  int get pileCount => _pile.length;

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
    _startNewGame(5); // Default to 5 players as requested (~middle of 2-10)
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

    _state = _state.copyWith(
      roomId: '101',
      participants: participants,
      myHand: hands['me']!,
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
        if (rank == UnitRank.joker) continue;
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
    _advanceTurn();
  }

  void startSession() {
    _startNewGame(5);
  }

  void raiseChallenge() {
    if (_lastMove == null) return;

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

    // Reset Round
    _currentRank = null;
    _lastMove = null;
    _stagedRank = null;

    _state = _state.copyWith(
      lastActionText: resultText,
      activeParticipantId: loserId, // Loser starts new round
    );
    notifyListeners();

    if (loserId != 'me') {
      _scheduleBotTurn(loserId);
    }
  }

  // ---------------------------------------------------------------------------
  // GAME ENGINE
  // ---------------------------------------------------------------------------

  void _executeMove(String playerId, List<Unit> units, UnitRank declaredRank) {
    _pile.addAll(units);

    _lastMove = _GameMove(
      playerId: playerId,
      declaredRank: declaredRank,
      actualUnits: units,
    );

    if (playerId == 'me') {
      final newHand = _state.myHand.where((u) => !units.contains(u)).toList();
      _state = _state.copyWith(myHand: newHand);
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
      _state = _state.copyWith(lastActionText: "${pNames[playerId]} WINS!");
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
    if (playerId == 'me') {
      final currentHand = [..._state.myHand, ..._pile];
      _state = _state.copyWith(myHand: currentHand);
    }

    final updatedParticipants = _state.participants.map((p) {
      if (p.id == playerId) {
        return p.copyWith(unitCount: p.unitCount + _pile.length);
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
    await Future.delayed(const Duration(milliseconds: 1500));

    // 1. Chance to Challenge
    if (_lastMove != null && _lastMove!.playerId != botId) {
      if (Random().nextDouble() < 0.2) {
        raiseChallenge();
        return;
      }
    }

    // 2. Play
    _currentRank ??=
        UnitRank.values[Random().nextInt(UnitRank.values.length - 1)];

    final int cardsToPlay = Random().nextInt(2) + 1;
    final bool isBluff = Random().nextDouble() > 0.7;

    List<Unit> botUnits;
    if (isBluff) {
      botUnits = List.generate(
        cardsToPlay,
        (_) => Unit(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          type: UnitType.spades,
          rank: _currentRank == UnitRank.ace ? UnitRank.king : UnitRank.ace,
        ),
      );
    } else {
      botUnits = List.generate(
        cardsToPlay,
        (_) => Unit(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          type: UnitType.hearts,
          rank: _currentRank!,
        ),
      );
    }

    _executeMove(botId, botUnits, _currentRank!);
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
