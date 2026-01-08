import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../data/repositories/profile_repository.dart';
import '../../../../core/error/failure.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repository;

  ProfileBloc({required ProfileRepository repository})
    : _repository = repository,
      super(ProfileInitial()) {
    on<ProfileViewRequested>(_onViewRequested);
    on<ProfileFriendAdded>(_onFriendAdded);
    on<ProfileFriendRemoved>(_onFriendRemoved);
  }

  Future<void> _onViewRequested(
    ProfileViewRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());

    try {
      final profile = await _repository.getProfile(event.userId);
      final currentUser = FirebaseAuth.instance.currentUser;
      final isOwnProfile = currentUser?.uid == event.userId;

      emit(ProfileLoaded(profile: profile, isOwnProfile: isOwnProfile));
    } catch (e) {
      emit(ProfileError(ServerFailure('Failed to load profile: $e')));
    }
  }

  Future<void> _onFriendAdded(
    ProfileFriendAdded event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await _repository.addFriend(event.userId);

      // Reload profile to update friend status
      add(ProfileViewRequested(event.userId));
    } catch (e) {
      emit(ProfileError(UnknownFailure('Failed to add friend: $e')));
    }
  }

  Future<void> _onFriendRemoved(
    ProfileFriendRemoved event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await _repository.removeFriend(event.userId);

      // Reload profile to update friend status
      add(ProfileViewRequested(event.userId));
    } catch (e) {
      emit(ProfileError(UnknownFailure('Failed to remove friend: $e')));
    }
  }
}
