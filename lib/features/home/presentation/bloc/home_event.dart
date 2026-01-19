import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_stats.dart';
import '../../../../core/models/system_status.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeStarted extends HomeEvent {}

class HomePlayOnlineClicked extends HomeEvent {
  final UserStats? stats;
  const HomePlayOnlineClicked(this.stats);
}

class HomeRejoinGameConfirmed extends HomeEvent {}

class HomeNewGameConfirmed extends HomeEvent {}

class HomeCreateRoomClicked extends HomeEvent {}

class HomeCreateHotspotClicked extends HomeEvent {}

class HomeJoinHotspotClicked extends HomeEvent {}

class HomeJoinRoomClicked extends HomeEvent {}

class HomeBotMatchClicked extends HomeEvent {}

class HomeFriendsMatchClicked extends HomeEvent {}

class HomeDailyChallengeClicked extends HomeEvent {}

class HomeBottomNavTapped extends HomeEvent {
  final int index;
  const HomeBottomNavTapped(this.index);
}

class HomeRefillCoinsClicked extends HomeEvent {}

class HomeSystemStatusChanged extends HomeEvent {
  final SystemStatus status;
  const HomeSystemStatusChanged(this.status);
}

class HomeSessionStateChanged extends HomeEvent {
  final bool hasActiveSession;
  const HomeSessionStateChanged(this.hasActiveSession);
}
