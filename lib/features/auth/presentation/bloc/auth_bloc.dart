import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/data/data.dart';
import '../../../../core/repositories/session_repository.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/error/failure.dart' as f;
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../../core/di/service_locator.dart' as di;

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final SessionRepository _sessionRepository;
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _statsSubscription;

  AuthBloc({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    required SessionRepository sessionRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _sessionRepository = sessionRepository,
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
    on<AuthSilentSignInRequested>(_onAuthSilentSignInRequested);
    on<AuthStatsUpdated>(_onAuthStatsUpdated);

    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      if (!isClosed && user != null) {
        add(AuthCheckRequested());
      }
    });

    _statsSubscription = di.sl.webSocketSessionHandler.statsStream.listen((
      stats,
    ) {
      if (!isClosed) {
        add(AuthStatsUpdated(stats));
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
      final user = _authRepository.currentUser;
      if (user != null) {
        await _userRepository.syncUser(user);
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      f.Failure failure;
      switch (e.code) {
        case 'ERROR_ABORTED_BY_USER':
        case 'canceled':
          failure = const f.AuthFailure('Sign-in was cancelled.');
          break;
        case 'network-request-failed':
          failure = const f.NetworkFailure();
          break;
        case 'invalid-credential':
          failure = const f.AuthFailure('Invalid credentials. Try again.');
          break;
        case 'user-disabled':
          failure = const f.AuthFailure('This account has been disabled.');
          break;
        default:
          failure = f.AuthFailure(
            e.message ?? 'Sign-in failed. Please try again.',
          );
      }
      emit(AuthFailure(failure));
    } catch (e) {
      emit(AuthFailure(f.UnknownFailure(ErrorMessages.getFromException(e))));
    }
  }

  Future<void> _onAuthSilentSignInRequested(
    AuthSilentSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authRepository.signInSilently();
      if (userCredential?.user != null) {
        await _userRepository.syncUser(userCredential!.user!);
        emit(Authenticated(userCredential.user!));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
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

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. Notify Backend to scrub data
      await _sessionRepository.deleteAccount();

      // 2. Delete from Firebase (handles re-auth internally)
      await _authRepository.deleteAccount();

      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure(f.UnknownFailure(ErrorMessages.getFromException(e))));
    }
  }

  void _onAuthStatsUpdated(AuthStatsUpdated event, Emitter<AuthState> emit) {
    if (state is Authenticated) {
      final currentState = state as Authenticated;
      emit(currentState.copyWith(stats: event.stats));
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    _statsSubscription?.cancel();
    return super.close();
  }
}
