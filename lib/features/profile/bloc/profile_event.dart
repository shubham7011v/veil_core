import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  final String uid;
  const ProfileLoadRequested(this.uid);

  @override
  List<Object?> get props => [uid];
}

class UpdateRoyalNameRequested extends ProfileEvent {
  final String name;
  const UpdateRoyalNameRequested(this.name);

  @override
  List<Object?> get props => [name];
}
