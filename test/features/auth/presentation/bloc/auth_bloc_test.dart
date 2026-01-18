import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:veil_core/features/auth/presentation/bloc/auth_event.dart';
import 'package:veil_core/features/auth/presentation/bloc/auth_state.dart';
import 'package:veil_core/core/data/repositories/auth_repository.dart';
import 'package:veil_core/core/data/repositories/user_repository.dart';
import 'package:veil_core/core/repositories/session_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSessionRepository extends Mock implements SessionRepository {}

class MockWebSocketSessionHandler extends Mock
    implements WebSocketSessionHandler {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockUserRepository mockUserRepository;
  late MockSessionRepository mockSessionRepository;
  late MockWebSocketSessionHandler mockWebSocketHandler;
  late AuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(MockUser());
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockUserRepository = MockUserRepository();
    mockSessionRepository = MockSessionRepository();
    mockWebSocketHandler = MockWebSocketSessionHandler();

    // Mock ServiceLocator access if possible or just use    // Inject mocks into ServiceLocator
    sl.webSocketSessionHandler = mockWebSocketHandler;

    // Stub necessary streams for AuthBloc
    when(
      () => mockWebSocketHandler.statsStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockWebSocketHandler.errorStream,
    ).thenAnswer((_) => const Stream.empty());

    // Mock auth state changes stream
    when(
      () => mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));

    authBloc = AuthBloc(
      authRepository: mockAuthRepository,
      userRepository: mockUserRepository,
      sessionRepository: mockSessionRepository,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] when GoogleSignInRequested succeeds',
      build: () {
        final mockUser = MockUser();
        final mockUserCredential = MockUserCredential();
        when(() => mockUser.uid).thenReturn('test-uid');
        when(() => mockUser.email).thenReturn('test@example.com');
        when(() => mockUser.displayName).thenReturn('Test User');
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(
          () => mockAuthRepository.signInWithGoogle(),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockAuthRepository.currentUser).thenReturn(mockUser);
        when(() => mockUserRepository.syncUser(any())).thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(GoogleSignInRequested()),
      expect: () => [isA<AuthLoading>(), isA<Authenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] when GoogleSignInRequested fails',
      build: () {
        when(
          () => mockAuthRepository.signInWithGoogle(),
        ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
        return authBloc;
      },
      act: (bloc) => bloc.add(GoogleSignInRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] when SignOutRequested',
      build: () {
        when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(SignOutRequested()),
      expect: () => [isA<AuthLoading>(), isA<Unauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] for silent sign in with no user',
      build: () {
        when(() => mockAuthRepository.currentUser).thenReturn(null);
        when(
          () => mockAuthRepository.signInSilently(),
        ).thenAnswer((_) async => null);
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthSilentSignInRequested()),
      wait: const Duration(milliseconds: 100),
      expect: () => [isA<AuthLoading>(), isA<Unauthenticated>()],
    );
  });

  group('Auth Check', () {
    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when user exists',
      build: () {
        final mockUser = MockUser();
        when(() => mockUser.uid).thenReturn('existing-uid');
        when(() => mockAuthRepository.currentUser).thenReturn(mockUser);
        when(() => mockUserRepository.syncUser(any())).thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<Authenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated when no user',
      build: () {
        when(() => mockAuthRepository.currentUser).thenReturn(null);
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<Unauthenticated>()],
    );
  });
}
