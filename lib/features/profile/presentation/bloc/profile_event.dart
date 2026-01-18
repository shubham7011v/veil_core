import 'package:equatable/equatable.dart';
import '../../domain/models/match_history_item.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileViewRequested extends ProfileEvent {
  final String userId;

  const ProfileViewRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ProfileFriendAdded extends ProfileEvent {
  final String userId;

  const ProfileFriendAdded(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ProfileFriendRemoved extends ProfileEvent {
  final String userId;

  const ProfileFriendRemoved(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ProfileMatchHistoryRequested extends ProfileEvent {
  const ProfileMatchHistoryRequested();
}

class ProfileMatchHistoryUpdated extends ProfileEvent {
  final List<MatchHistoryItem> history;

  const ProfileMatchHistoryUpdated(this.history);
  @override
  List<Object?> get props => [history];
}
