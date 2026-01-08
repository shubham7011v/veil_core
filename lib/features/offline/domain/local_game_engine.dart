import 'dart:async';
import 'dart:math';
import 'models/offline_models.dart';

class LocalGameEngine {
  final _stateController = StreamController<OfflineGameState>.broadcast();
  OfflineGameState _state = const OfflineGameState();

  Stream<OfflineGameState> get stateStream => _stateController.stream;
  OfflineGameState get state => _state;

  void _updateState(OfflineGameState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  // -- Player Management --

  void addPlayer(String id, String name) {
    if (_state.phase != OfflinePhase.lobby) return;
    if (_state.players.length >= 8) return; // Max players
    if (_state.playerMap.containsKey(id)) return;

    final player = OfflinePlayer(id: id, name: name);
    final newPlayers = List<OfflinePlayer>.from(_state.players)..add(player);
    final newPlayerMap = Map<String, OfflinePlayer>.from(_state.playerMap)
      ..[id] = player;

    _updateState(_state.copyWith(players: newPlayers, playerMap: newPlayerMap));
    _syncParticipants();
  }

  void removePlayer(String id) {
    if (!_state.playerMap.containsKey(id)) return;

    final newPlayers = _state.players.where((p) => p.id != id).toList();
    final newPlayerMap = Map<String, OfflinePlayer>.from(_state.playerMap)
      ..remove(id);

    _updateState(_state.copyWith(players: newPlayers, playerMap: newPlayerMap));
    _syncParticipants();
  }

  // -- Game Actions --

  void start() {
    if (_state.players.length < 2) return;

    // 1. Shuffle Players for Turn Order
    final rng = Random();
    final players = List<OfflinePlayer>.from(_state.players)..shuffle(rng);
    final turnOrder = players.map((p) => p.id).toList();

    // 2. Local Deck Generation
    final deck = _generateDeck();
    deck.shuffle(rng);

    // 3. Deal
    final cardsPerPlayer = deck.length ~/ players.length;
    final updatedPlayers = <OfflinePlayer>[];
    int cursor = 0;

    for (int i = 0; i < players.length; i++) {
      int end = cursor + cardsPerPlayer;
      if (i < deck.length % players.length) {
        end++; // Give remainders to first few players
      }
      if (end > deck.length) end = deck.length;

      final playerHand = deck.sublist(cursor, end);
      updatedPlayers.add(players[i].copyWith(hand: playerHand));
      cursor = end;
    }

    final newPlayerMap = {for (var p in updatedPlayers) p.id: p};

    _updateState(
      OfflineGameState(
        phase: OfflinePhase.thinking,
        players: updatedPlayers,
        playerMap: newPlayerMap,
        turnOrder: turnOrder,
        activeIdx: 0,
        pile: const [],
      ),
    );
    _syncParticipants();
  }

  void playCards(
    String playerID,
    List<String> cardIDs,
    OfflineRank declaredRank,
  ) {
    if (_state.phase != OfflinePhase.thinking) return;
    if (_state.activePlayerID != playerID) return;
    if (cardIDs.isEmpty || cardIDs.length > 4) return;

    final player = _state.playerMap[playerID]!;
    if (!_hasCards(player, cardIDs)) return;

    if (_state.declaredRank != null && _state.declaredRank != declaredRank) {
      return; // Must play current round rank
    }

    // Move cards Hand -> Pile
    final removed = _removeCards(player, cardIDs);
    final newHand = removed.remaining;
    final actualCards = removed.removed;

    final newPile = List<OfflineCard>.from(_state.pile)..addAll(actualCards);
    final newPlayerMap = Map<String, OfflinePlayer>.from(_state.playerMap)
      ..[playerID] = player.copyWith(hand: newHand);

    final lastMove = OfflineLastMove(
      playerID: playerID,
      declaredRank: declaredRank,
      actualCards: actualCards,
      timestamp: DateTime.now(),
    );

    _updateState(
      OfflineGameState(
        phase: OfflinePhase.challenging,
        players: newPlayerMap.values.toList(),
        playerMap: newPlayerMap,
        turnOrder: _state.turnOrder,
        activeIdx: (_state.activeIdx + 1) % _state.turnOrder.length,
        pile: newPile,
        lastMove: lastMove,
        declaredRank: _state.declaredRank ?? declaredRank,
      ),
    );
    _syncParticipants();
  }

  void challenge(String challengerID) {
    if (_state.phase != OfflinePhase.challenging) return;
    if (_state.activePlayerID != challengerID) return;
    if (_state.lastMove == null) return;

    final lastMove = _state.lastMove!;
    final blufferID = lastMove.playerID;
    final declared = lastMove.declaredRank;
    final actual = lastMove.actualCards;

    bool isBluff = actual.any((c) => c.rank != declared);
    final loserID = isBluff ? blufferID : challengerID;
    final winnerID = isBluff ? challengerID : blufferID;

    _givePileTo(loserID);
    _resetRound(winnerID);
    _syncParticipants();
  }

  void pass(String playerID) {
    if (_state.activePlayerID != playerID) return;

    final player = _state.playerMap[playerID]!;
    final newPlayerMap = Map<String, OfflinePlayer>.from(_state.playerMap)
      ..[playerID] = player.copyWith(hasPassed: true);

    _updateState(
      _state.copyWith(
        playerMap: newPlayerMap,
        players: newPlayerMap.values.toList(),
      ),
    );

    if (_checkAllPassed()) {
      // Round ends, original mover starts new
      final nextPlayerID = _state.lastMove?.playerID ?? _state.activePlayerID;
      _resetRound(nextPlayerID);
    } else {
      _updateState(
        _state.copyWith(
          activeIdx: (_state.activeIdx + 1) % _state.turnOrder.length,
        ),
      );
    }
    _syncParticipants();
  }

  // -- Internal Helpers --

  void _syncParticipants() {
    final activeID = _state.activePlayerID;
    final participants = _state.players.map((p) {
      return OfflinePublicParticipant(
        id: p.id,
        name: p.name,
        cardCount: p.hand.length,
        isActive: (p.id == activeID) && (_state.phase != OfflinePhase.finished),
      );
    }).toList();

    _updateState(_state.copyWith(participants: participants));
  }

  void _givePileTo(String playerID) {
    final player = _state.playerMap[playerID]!;
    final newHand = List<OfflineCard>.from(player.hand)..addAll(_state.pile);
    final newPlayerMap = Map<String, OfflinePlayer>.from(_state.playerMap)
      ..[playerID] = player.copyWith(hand: newHand);

    _updateState(
      _state.copyWith(
        playerMap: newPlayerMap,
        players: newPlayerMap.values.toList(),
        pile: const [],
      ),
    );
  }

  void _resetRound(String nextPlayerID) {
    // Check for game over
    for (var p in _state.players) {
      if (p.hand.isEmpty) {
        _updateState(
          _state.copyWith(phase: OfflinePhase.finished, winnerID: p.id),
        );
        return;
      }
    }

    int nextIdx = _state.turnOrder.indexOf(nextPlayerID);
    if (nextIdx == -1) nextIdx = 0;

    final resetPlayers = _state.players
        .map((p) => p.copyWith(hasPassed: false))
        .toList();
    final resetMap = {for (var p in resetPlayers) p.id: p};

    _updateState(
      _state.copyWith(
        phase: OfflinePhase.thinking,
        declaredRank: null,
        lastMove: null,
        activeIdx: nextIdx,
        players: resetPlayers,
        playerMap: resetMap,
        pile: const [],
      ),
    );
  }

  bool _checkAllPassed() {
    int passCount = _state.players.where((p) => p.hasPassed).length;
    return passCount >= (_state.players.length - 1);
  }

  List<OfflineCard> _generateDeck() {
    final deck = <OfflineCard>[];
    for (var suit in OfflineSuit.values) {
      for (var rank in OfflineRank.values) {
        deck.add(
          OfflineCard(
            id: '${rank.name}_of_${suit.name}',
            suit: suit,
            rank: rank,
          ),
        );
      }
    }
    return deck;
  }

  bool _hasCards(OfflinePlayer p, List<String> cardIDs) {
    final handIDs = p.hand.map((c) => c.id).toSet();
    return cardIDs.every((id) => handIDs.contains(id));
  }

  ({List<OfflineCard> removed, List<OfflineCard> remaining}) _removeCards(
    OfflinePlayer p,
    List<String> cardIDs,
  ) {
    final removed = p.hand.where((c) => cardIDs.contains(c.id)).toList();
    final remaining = p.hand.where((c) => !cardIDs.contains(c.id)).toList();
    return (removed: removed, remaining: remaining);
  }

  void dispose() {
    _stateController.close();
  }
}

extension on OfflineGameState {
  OfflineGameState copyWith({
    OfflinePhase? phase,
    List<OfflinePlayer>? players,
    Map<String, OfflinePlayer>? playerMap,
    List<OfflinePublicParticipant>? participants,
    List<String>? turnOrder,
    int? activeIdx,
    List<OfflineCard>? pile,
    OfflineLastMove? lastMove,
    OfflineRank? declaredRank,
    String? winnerID,
  }) {
    return OfflineGameState(
      phase: phase ?? this.phase,
      players: players ?? this.players,
      playerMap: playerMap ?? this.playerMap,
      participants: participants ?? this.participants,
      turnOrder: turnOrder ?? this.turnOrder,
      activeIdx: activeIdx ?? this.activeIdx,
      pile: pile ?? this.pile,
      lastMove: lastMove ?? this.lastMove,
      declaredRank: declaredRank ?? this.declaredRank,
      winnerID: winnerID ?? this.winnerID,
    );
  }
}
