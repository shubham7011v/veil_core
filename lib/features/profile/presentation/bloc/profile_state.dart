import 'package:equatable/equatable.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/match_history_item.dart';
import '../../../../core/error/failure.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserProfile profile;
  final bool isOwnProfile;
  final List<MatchHistoryItem> matchHistory;

  const ProfileLoaded({
    required this.profile,
    required this.isOwnProfile,
    this.matchHistory = const [],
  });

  ProfileLoaded copyWith({
    UserProfile? profile,
    bool? isOwnProfile,
    List<MatchHistoryItem>? matchHistory,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      matchHistory: matchHistory ?? this.matchHistory,
    );
  }

  @override
  List<Object?> get props => [profile, isOwnProfile, matchHistory];
}

class ProfileError extends ProfileState {
  final Failure failure;

  const ProfileError(this.failure);

  @override
  List<Object?> get props => [failure];
}
