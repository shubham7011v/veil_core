import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/models/daily_challenge.dart';
import '../../data/challenges_repository.dart';

// Events
abstract class ChallengesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadChallenges extends ChallengesEvent {}

class ClaimChallenge extends ChallengesEvent {
  final String challengeId;
  ClaimChallenge(this.challengeId);
  @override
  List<Object?> get props => [challengeId];
}

class _UpdateChallenges extends ChallengesEvent {
  final List<DailyChallenge> challenges;
  _UpdateChallenges(this.challenges);
  @override
  List<Object?> get props => [challenges];
}

// State
abstract class ChallengesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChallengesInitial extends ChallengesState {}

class ChallengesLoading extends ChallengesState {}

class ChallengesLoaded extends ChallengesState {
  final List<DailyChallenge> challenges;
  ChallengesLoaded(this.challenges);
  @override
  List<Object?> get props => [challenges];
}

class ChallengesError extends ChallengesState {
  final String message;
  ChallengesError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  final ChallengesRepository _repository;
  StreamSubscription? _subscription;

  ChallengesBloc(this._repository) : super(ChallengesInitial()) {
    on<LoadChallenges>(_onLoadChallenges);
    on<ClaimChallenge>(_onClaimChallenge);
    on<_UpdateChallenges>(_onUpdateChallenges);

    _subscription = _repository.challengesStream.listen((challenges) {
      add(_UpdateChallenges(challenges));
    });
  }

  void _onLoadChallenges(LoadChallenges event, Emitter<ChallengesState> emit) {
    emit(ChallengesLoading());
    _repository.fetchChallenges();
  }

  void _onClaimChallenge(ClaimChallenge event, Emitter<ChallengesState> emit) {
    _repository.claimReward(event.challengeId);
  }

  void _onUpdateChallenges(
    _UpdateChallenges event,
    Emitter<ChallengesState> emit,
  ) {
    emit(ChallengesLoaded(event.challenges));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
