import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../../../../core/error/failure.dart';

class SessionBlocState extends Equatable {
  final engine.SessionState engineState;

  // -- UI Selection State --
  final List<String> selectedUnitIds;
  final engine.UnitRank? stagedRank;
  final bool isSelectingRank;

  // -- Event State for Animations --
  final engine.SessionEventType lastEvent;
  final String? lastEventActorId;
  final int lastEventCardCount;
  final bool isRevealingBluff;
  final engine.GameMove? lastMove;
  final int
  lastEventTimestamp; // Used to trigger animations on same-type events

  // -- Player Info --
  final Map<String, String> pNames;

  // -- Game History --
  final List<String> gameLog;
  final List<Map<String, dynamic>> chatMessages;

  // -- Error State --
  final Failure? failure;

  const SessionBlocState({
    required this.engineState,
    required this.selectedUnitIds,
    this.stagedRank,
    required this.isSelectingRank,
    required this.lastEvent,
    this.lastEventActorId,
    this.lastEventCardCount = 0,
    required this.isRevealingBluff,
    this.lastMove,
    this.lastEventTimestamp = 0,
    required this.pNames,
    required this.gameLog,
    required this.chatMessages,
    this.failure,
  });

  factory SessionBlocState.initial() => SessionBlocState(
    engineState: engine.SessionState.initial(),
    selectedUnitIds: const [],
    isSelectingRank: false,
    lastEvent: engine.SessionEventType.none,
    isRevealingBluff: false,
    lastEventTimestamp: 0,
    pNames: const {},
    gameLog: const [],
    chatMessages: const [],
  );

  SessionBlocState copyWith({
    engine.SessionState? engineState,
    List<String>? selectedUnitIds,
    engine.UnitRank? stagedRank,
    bool? isSelectingRank,
    engine.SessionEventType? lastEvent,
    String? lastEventActorId,
    int? lastEventCardCount,
    bool? isRevealingBluff,
    engine.GameMove? lastMove,
    int? lastEventTimestamp,
    Map<String, String>? pNames,
    List<String>? gameLog,
    List<Map<String, dynamic>>? chatMessages,
    Failure? failure,
    bool clearStagedRank = false,
    bool clearLastMove = false,
    bool clearFailure = false,
  }) {
    return SessionBlocState(
      engineState: engineState ?? this.engineState,
      selectedUnitIds: selectedUnitIds ?? this.selectedUnitIds,
      stagedRank: clearStagedRank ? null : (stagedRank ?? this.stagedRank),
      isSelectingRank: isSelectingRank ?? this.isSelectingRank,
      lastEvent: lastEvent ?? this.lastEvent,
      lastEventActorId: lastEventActorId ?? this.lastEventActorId,
      lastEventCardCount: lastEventCardCount ?? this.lastEventCardCount,
      isRevealingBluff: isRevealingBluff ?? this.isRevealingBluff,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      lastEventTimestamp: lastEventTimestamp ?? this.lastEventTimestamp,
      pNames: pNames ?? this.pNames,
      gameLog: gameLog ?? this.gameLog,
      chatMessages: chatMessages ?? this.chatMessages,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  // -- Derived Getters --
  bool get isMyTurn => engineState.activeParticipantId == 'me';

  // Show rank selector only when explicitly toggled via isSelectingRank
  bool get shouldShowRankSelector => isSelectingRank && !isRoundSet;

  bool get isRoundSet => lastMove != null;

  int get pileCount => engineState.pileCount;

  String get roundStatus {
    if (isRoundSet) return "${lastMove!.declaredRank.name.toUpperCase()}S";
    return stagedRank?.name.toUpperCase() ?? "WAITING";
  }

  String getPlayerName(String id) => pNames[id] ?? id;

  bool get canSubmit {
    if (!isMyTurn) return false;
    if (selectedUnitIds.isEmpty) return false;
    if (!isRoundSet && stagedRank == null) return false;
    return true;
  }

  @override
  List<Object?> get props => [
    engineState,
    selectedUnitIds,
    stagedRank,
    isSelectingRank,
    lastEvent,
    lastEventActorId,
    lastEventCardCount,
    isRevealingBluff,
    lastMove,
    lastEventTimestamp,
    pNames,
    gameLog,
    chatMessages,
    failure,
  ];
}
