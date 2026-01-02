import 'package:equatable/equatable.dart';
import '../models/session_state.dart' as model;
import '../models/session_enums.dart';
import '../models/unit.dart';

class SessionBlocState extends Equatable {
  final model.SessionState engineState;

  // -- UI Selection State --
  final List<String> selectedUnitIds;
  final UnitRank? stagedRank;
  final bool isSelectingRank;

  // -- Event State for Animations --
  final SessionEventType lastEvent;
  final String? lastEventActorId;
  final int lastEventCardCount;

  const SessionBlocState({
    required this.engineState,
    required this.selectedUnitIds,
    this.stagedRank,
    required this.isSelectingRank,
    required this.lastEvent,
    this.lastEventActorId,
    this.lastEventCardCount = 0,
  });

  factory SessionBlocState.initial() => SessionBlocState(
    engineState: model.SessionState.initial(),
    selectedUnitIds: const [],
    isSelectingRank: false,
    lastEvent: SessionEventType.none,
  );

  SessionBlocState copyWith({
    model.SessionState? engineState,
    List<String>? selectedUnitIds,
    UnitRank? stagedRank,
    bool? isSelectingRank,
    SessionEventType? lastEvent,
    String? lastEventActorId,
    int? lastEventCardCount,
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
    );
  }

  // -- Derived Getters --
  bool get isMyTurn => engineState.activeParticipantId == 'me';
  bool get shouldShowRankSelector => isMyTurn && isSelectingRank;

  bool canSubmit(bool isRoundSet) {
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
  ];
}
