import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_stats.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserStats user;
  const ProfileLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

class ProfileFailure extends ProfileState {
  final String message;
  const ProfileFailure(this.message);

  @override
  List<Object?> get props => [message];
}
