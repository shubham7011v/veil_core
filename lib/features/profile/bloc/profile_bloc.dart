import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/error_messages.dart';
import '../repositories/user_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UserRepository _userRepository;

  ProfileBloc({required UserRepository userRepository})
    : _userRepository = userRepository,
      super(ProfileInitial()) {
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<UpdateRoyalNameRequested>(_onUpdateRoyalNameRequested);
  }

  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final user = await _userRepository.getUser(event.uid);
      if (user != null) {
        emit(ProfileLoaded(user));
      } else {
        emit(const ProfileError('User not found'));
      }
    } catch (e) {
      emit(ProfileError(ErrorMessages.getFromException(e)));
    }
  }

  Future<void> _onUpdateRoyalNameRequested(
    UpdateRoyalNameRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      try {
        final updatedUser = currentState.user.copyWith(
          name: event.name,
          isNameSet: true,
        );
        await _userRepository.updateUser(updatedUser);
        emit(ProfileLoaded(updatedUser));
      } catch (e) {
        emit(ProfileError(ErrorMessages.getFromException(e)));
      }
    }
  }
}
