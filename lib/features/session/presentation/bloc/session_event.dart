import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../../../../core/error/failure.dart';

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

class SessionHandlerSwapped extends SessionEvent {
  final engine.GameSessionHandler newHandler;
  const SessionHandlerSwapped(this.newHandler);

  @override
  List<Object?> get props => [newHandler];
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

// -- Error Events --
class SessionErrorOccurred extends SessionEvent {
  final Failure error;
  const SessionErrorOccurred(this.error);

  @override
  List<Object?> get props => [error];
}

class SessionErrorCleared extends SessionEvent {
  const SessionErrorCleared();
}

// -- Chat Events --

class SendChatMessage extends SessionEvent {
  final String message;
  const SendChatMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class SendEmojiMessage extends SessionEvent {
  final String emojiId;
  const SendEmojiMessage(this.emojiId);

  @override
  List<Object?> get props => [emojiId];
}

class ChatStreamUpdated extends SessionEvent {
  final Map<String, dynamic> message;
  const ChatStreamUpdated(this.message);

  @override
  List<Object?> get props => [message];
}

class SendTypingStatus extends SessionEvent {
  final bool isTyping;
  const SendTypingStatus(this.isTyping);

  @override
  List<Object?> get props => [isTyping];
}

class TypingStatusChanged extends SessionEvent {
  final String senderId;
  final bool isTyping;
  const TypingStatusChanged(this.senderId, this.isTyping);

  @override
  List<Object?> get props => [senderId, isTyping];
}
