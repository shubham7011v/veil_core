import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/user_stats.dart';
import '../../../../core/error/failure.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final User user;
  final UserStats? stats;

  const Authenticated(this.user, {this.stats});

  Authenticated copyWith({User? user, UserStats? stats}) {
    return Authenticated(user ?? this.user, stats: stats ?? this.stats);
  }

  @override
  List<Object?> get props => [user, stats];
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final Failure failure;
  const AuthFailure(this.failure);

  @override
  List<Object?> get props => [failure];

  @override
  String toString() => failure.toString();
}
