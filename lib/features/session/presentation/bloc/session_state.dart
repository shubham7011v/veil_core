import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart' as engine;

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

  // -- Player Info --
  final Map<String, String> pNames;

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
    required this.pNames,
  });

  factory SessionBlocState.initial() => SessionBlocState(
    engineState: engine.SessionState.initial(),
    selectedUnitIds: const [],
    isSelectingRank: false,
    lastEvent: engine.SessionEventType.none,
    isRevealingBluff: false,
    pNames: const {},
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
    Map<String, String>? pNames,
    bool clearStagedRank = false,
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
      lastMove: lastMove ?? this.lastMove,
      pNames: pNames ?? this.pNames,
    );
  }

  // -- Derived Getters --
  bool get isMyTurn => engineState.activeParticipantId == 'me';

  // Show rank selector only when explicitly toggled via isSelectingRank
  bool get shouldShowRankSelector => isSelectingRank && !isRoundSet;

  bool get isRoundSet => lastMove != null;

  int get pileCount => engineState.pileCount;

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
    pNames,
  ];
}
