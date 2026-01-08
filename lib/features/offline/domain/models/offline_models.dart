import 'package:equatable/equatable.dart';

enum OfflinePhase { lobby, thinking, challenging, finished }

enum OfflineSuit { spades, hearts, diamonds, clubs }

enum OfflineRank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

class OfflineCard extends Equatable {
  final String id;
  final OfflineSuit suit;
  final OfflineRank rank;

  const OfflineCard({required this.id, required this.suit, required this.rank});

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': suit.name, // Go server uses 'type' for suit name
    'rank': rank.name,
  };

  @override
  List<Object?> get props => [id, suit, rank];
}

class OfflinePlayer extends Equatable {
  final String id;
  final String name;
  final List<OfflineCard> hand;
  final bool isConnected;
  final bool hasPassed;

  const OfflinePlayer({
    required this.id,
    required this.name,
    this.hand = const [],
    this.isConnected = true,
    this.hasPassed = false,
  });

  OfflinePlayer copyWith({
    String? name,
    List<OfflineCard>? hand,
    bool? isConnected,
    bool? hasPassed,
  }) {
    return OfflinePlayer(
      id: id,
      name: name ?? this.name,
      hand: hand ?? this.hand,
      isConnected: isConnected ?? this.isConnected,
      hasPassed: hasPassed ?? this.hasPassed,
    );
  }

  @override
  List<Object?> get props => [id, name, hand, isConnected, hasPassed];
}

class OfflinePublicParticipant {
  final String id;
  final String name;
  final int cardCount;
  final bool isActive;

  OfflinePublicParticipant({
    required this.id,
    required this.name,
    required this.cardCount,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cardCount': cardCount,
    'isActive': isActive,
  };
}

class OfflineLastMove {
  final String playerID;
  final OfflineRank declaredRank;
  final List<OfflineCard> actualCards;
  final DateTime timestamp;

  OfflineLastMove({
    required this.playerID,
    required this.declaredRank,
    required this.actualCards,
    required this.timestamp,
  });
}

class OfflineGameState extends Equatable {
  final OfflinePhase phase;
  final List<OfflinePlayer> players;
  final Map<String, OfflinePlayer> playerMap;
  final List<OfflinePublicParticipant> participants;
  final List<String> turnOrder;
  final int activeIdx;
  final List<OfflineCard> pile;
  final OfflineLastMove? lastMove;
  final OfflineRank? declaredRank;
  final String? winnerID;

  const OfflineGameState({
    this.phase = OfflinePhase.lobby,
    this.players = const [],
    this.playerMap = const {},
    this.participants = const [],
    this.turnOrder = const [],
    this.activeIdx = 0,
    this.pile = const [],
    this.lastMove,
    this.declaredRank,
    this.winnerID,
  });

  String get activePlayerID => turnOrder.isNotEmpty ? turnOrder[activeIdx] : '';

  Map<String, dynamic> toPublicJson() => {
    'phase': phase.name,
    'participants': participants.map((p) => p.toJson()).toList(),
    'pileCount': pile.length,
    'declaredRank': declaredRank?.name,
    'winnerId': winnerID,
    'activePlayerId': activePlayerID,
    'turnOrder': turnOrder,
  };

  @override
  List<Object?> get props => [
    phase,
    players,
    playerMap,
    participants,
    turnOrder,
    activeIdx,
    pile,
    lastMove,
    declaredRank,
    winnerID,
  ];
}
