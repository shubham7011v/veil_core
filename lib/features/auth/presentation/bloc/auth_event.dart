import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_stats.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSilentSignInRequested extends AuthEvent {}

class GoogleSignInRequested extends AuthEvent {}

class SignOutRequested extends AuthEvent {}

class AuthStatsUpdated extends AuthEvent {
  final UserStats stats;
  const AuthStatsUpdated(this.stats);

  @override
  List<Object?> get props => [stats];
}
