import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart';

abstract class MatchmakingEvent extends Equatable {
  const MatchmakingEvent();

  @override
  List<Object?> get props => [];
}

class StartMatchmaking extends MatchmakingEvent {}

class UpdateParticipants extends MatchmakingEvent {
  final List<Participant> participants;
  const UpdateParticipants(this.participants);

  @override
  List<Object?> get props => [participants];
}

class UpdateConnectionStatus extends MatchmakingEvent {
  final ConnectionStatus status;
  const UpdateConnectionStatus(this.status);

  @override
  List<Object?> get props => [status];
}

class UpdateTimer extends MatchmakingEvent {
  final int secondsRemaining;
  const UpdateTimer(this.secondsRemaining);

  @override
  List<Object?> get props => [secondsRemaining];
}

class MatchFound extends MatchmakingEvent {}

class CancelMatchmaking extends MatchmakingEvent {}

class TriggerError extends MatchmakingEvent {
  final String message;
  const TriggerError(this.message);

  @override
  List<Object?> get props => [message];
}

class SyncLobbyCreatedAt extends MatchmakingEvent {
  final int createdAt;
  const SyncLobbyCreatedAt(this.createdAt);

  @override
  List<Object?> get props => [createdAt];
}
