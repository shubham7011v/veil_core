import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';
import '../../profile/repositories/user_repository.dart';
import '../../../core/utils/error_messages.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  StreamSubscription? _authStateSubscription;

  AuthBloc({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);

    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        add(AuthCheckRequested());
      }
    });
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      await _userRepository.syncUser(user);
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithGoogle();
      // AuthCheckRequested will be triggered by the listener or we can emit here
      final user = _authRepository.currentUser;
      if (user != null) {
        await _userRepository.syncUser(user);
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Sign-in failed. Please try again.';
      switch (e.code) {
        case 'ERROR_ABORTED_BY_USER':
        case 'canceled':
          message = 'Sign-in was cancelled.';
          break;
        case 'network-request-failed':
          message = 'No internet connection.';
          break;
        case 'invalid-credential':
          message = 'Invalid credentials. Try again.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
      }
      emit(AuthFailure(message));
    } catch (e) {
      emit(AuthFailure(ErrorMessages.getFromException(e)));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _authRepository.signOut();
    emit(Unauthenticated());
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
