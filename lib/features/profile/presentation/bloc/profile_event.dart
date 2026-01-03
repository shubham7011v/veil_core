import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {}

class ProfileNameUpdateRequested extends ProfileEvent {
  final String newName;
  const ProfileNameUpdateRequested(this.newName);

  @override
  List<Object?> get props => [newName];
}

class ProfileAvatarUpdateRequested extends ProfileEvent {
  final String newAvatarUrl;
  const ProfileAvatarUpdateRequested(this.newAvatarUrl);

  @override
  List<Object?> get props => [newAvatarUrl];
}
