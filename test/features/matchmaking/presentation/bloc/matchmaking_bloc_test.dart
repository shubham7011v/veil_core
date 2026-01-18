import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/features/matchmaking/presentation/bloc/matchmaking_bloc.dart';
import 'package:veil_core/features/matchmaking/presentation/bloc/matchmaking_event.dart';
import 'package:veil_core/features/matchmaking/presentation/bloc/matchmaking_state.dart';
import 'package:veil_core/core/data/repositories/auth_repository.dart';
import 'package:veil_core/core/engine/domain/models/session_enums.dart';
import 'package:veil_core/core/engine/domain/models/session_state.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';

class MockWebSocketSessionHandler extends Mock
    implements WebSocketSessionHandler {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockWebSocketSessionHandler mockHandler;
  late MockAuthRepository mockAuthRepository;
  late MatchmakingBloc matchmakingBloc;

  setUp(() {
    mockHandler = MockWebSocketSessionHandler();
    mockAuthRepository = MockAuthRepository();

    // Stub common handler methods used during initialization or StartMatchmaking
    when(
      () => mockHandler.connectionStatus,
    ).thenReturn(ConnectionStatus.disconnected);
    when(
      () => mockHandler.connectionStatusStream,
    ).thenReturn(const Stream.empty());
    when(() => mockHandler.errorStream).thenReturn(const Stream.empty());
    when(() => mockHandler.sessionStateStream).thenReturn(const Stream.empty());
    when(() => mockHandler.roomEventStream).thenReturn(const Stream.empty());
    when(() => mockHandler.currentState).thenReturn(
      const SessionState(
        roomId: '000',
        participants: [],
        myHand: [],
        pileCount: 0,
        currentPhase: SessionPhase.lobby,
      ),
    );
    when(() => mockHandler.resetGameSession()).thenReturn(null);

    matchmakingBloc = MatchmakingBloc(
      handler: mockHandler,
      authRepository: mockAuthRepository,
    );
  });

  tearDown(() {
    matchmakingBloc.close();
  });

  group('MatchmakingBloc', () {
    test('initial state handles defaults', () {
      expect(matchmakingBloc.state.isMatchFound, false);
      expect(
        matchmakingBloc.state.connectionStatus,
        ConnectionStatus.disconnected,
      );
    });

    blocTest<MatchmakingBloc, MatchmakingState>(
      'emits state with isConnecting true and then false on error when StartMatchmaking is added',
      build: () {
        when(() => mockAuthRepository.currentUser).thenReturn(null);
        return matchmakingBloc;
      },
      act: (bloc) => bloc.add(StartMatchmaking()),
      expect: () => [
        isA<MatchmakingState>().having(
          (s) => s.isConnecting,
          'isConnecting',
          true,
        ),
        isA<MatchmakingState>()
            .having((s) => s.isConnecting, 'isConnecting', false)
            .having(
              (s) => s.error,
              'error',
              contains('Authentication required'),
            ),
      ],
    );

    blocTest<MatchmakingBloc, MatchmakingState>(
      'emits state with updated status when UpdateConnectionStatus is added',
      build: () => matchmakingBloc,
      act: (bloc) =>
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.connected)),
      expect: () => [
        isA<MatchmakingState>().having(
          (s) => s.connectionStatus,
          'status',
          ConnectionStatus.connected,
        ),
      ],
    );

    blocTest<MatchmakingBloc, MatchmakingState>(
      'emits state with isMatchFound true when MatchFound is added',
      build: () => matchmakingBloc,
      act: (bloc) => bloc.add(MatchFound()),
      expect: () => [
        isA<MatchmakingState>().having(
          (s) => s.isMatchFound,
          'isMatchFound',
          true,
        ),
      ],
    );
  });
}
