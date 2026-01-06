import 'package:equatable/equatable.dart';
import '../../domain/models/user_profile.dart';

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

  const ProfileLoaded({required this.profile, required this.isOwnProfile});

  @override
  List<Object?> get props => [profile, isOwnProfile];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
