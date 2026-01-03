import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/data/data.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  ProfileBloc({
    required UserRepository userRepository,
    required AuthRepository authRepository,
  }) : _userRepository = userRepository,
       _authRepository = authRepository,
       super(ProfileInitial()) {
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<ProfileNameUpdateRequested>(_onProfileNameUpdateRequested);
    on<ProfileAvatarUpdateRequested>(_onProfileAvatarUpdateRequested);
  }

  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final user = await _userRepository.getUser(
        _authRepository.currentUser?.uid ?? '',
      );
      if (user != null) {
        emit(ProfileLoaded(user));
      } else {
        emit(const ProfileFailure("User not found"));
      }
    } catch (e) {
      emit(ProfileFailure(e.toString()));
    }
  }

  Future<void> _onProfileNameUpdateRequested(
    ProfileNameUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await _userRepository.updateDisplayName(
        _authRepository.currentUser?.uid ?? '',
        event.newName,
      );
      add(ProfileLoadRequested());
    } catch (e) {
      emit(ProfileFailure(e.toString()));
    }
  }

  Future<void> _onProfileAvatarUpdateRequested(
    ProfileAvatarUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await _userRepository.updateAvatarUrl(
        _authRepository.currentUser?.uid ?? '',
        event.newAvatarUrl,
      );
      add(ProfileLoadRequested());
    } catch (e) {
      emit(ProfileFailure(e.toString()));
    }
  }
}
