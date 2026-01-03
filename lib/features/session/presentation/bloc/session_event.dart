import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart' as engine;

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

// -- Action Events --
class SessionStartRequested extends SessionEvent {
  final int playerCount;
  final int thinkingTimeS;

  const SessionStartRequested({this.playerCount = 5, this.thinkingTimeS = 10});

  @override
  List<Object?> get props => [playerCount, thinkingTimeS];
}

class SessionResetRequested extends SessionEvent {
  const SessionResetRequested();
}

class UnitToggled extends SessionEvent {
  final String unitId;
  const UnitToggled(this.unitId);

  @override
  List<Object?> get props => [unitId];
}

class RankStaged extends SessionEvent {
  final engine.UnitRank rank;
  const RankStaged(this.rank);

  @override
  List<Object?> get props => [rank];
}

class RankSelectionToggleRequested extends SessionEvent {}

class CardsPlayRequested extends SessionEvent {}

class TurnPassRequested extends SessionEvent {}

class ChallengeRaiseRequested extends SessionEvent {}

class HandSortRequested extends SessionEvent {}

class HandReorderRequested extends SessionEvent {
  final int oldIndex;
  final int newIndex;

  const HandReorderRequested(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

// -- Engine Update Events --
class EngineStateUpdated extends SessionEvent {
  final engine.SessionState state;
  const EngineStateUpdated(this.state);

  @override
  List<Object?> get props => [state];
}

class EngineEventReceived extends SessionEvent {
  final engine.SessionEventType type;
  final String? actorId;
  final int cardCount;

  const EngineEventReceived(this.type, this.actorId, {this.cardCount = 0});

  @override
  List<Object?> get props => [type, actorId, cardCount];
}

class HandlerSyncRequested extends SessionEvent {
  const HandlerSyncRequested();
}
