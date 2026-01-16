import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/features/matchmaking/presentation/bloc/matchmaking_bloc.dart';
import 'package:veil_core/features/matchmaking/presentation/bloc/matchmaking_event.dart';
import 'package:veil_core/features/matchmaking/presentation/bloc/matchmaking_state.dart';
import 'package:veil_core/core/engine/engine.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';

// Mock classes
class MockWebSocketSessionHandler extends Mock
    implements WebSocketSessionHandler {}

void main() {
  late MockWebSocketSessionHandler mockHandler;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(ConnectionStatus.disconnected);
  });

  setUp(() {
    mockHandler = MockWebSocketSessionHandler();

    // Setup default stubs
    when(
      () => mockHandler.connectionStatus,
    ).thenReturn(ConnectionStatus.disconnected);
    when(() => mockHandler.statsStream).thenAnswer((_) => const Stream.empty());
    when(() => mockHandler.errorStream).thenAnswer((_) => const Stream.empty());
    when(
      () => mockHandler.connectionStatusStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockHandler.sessionStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockHandler.roomEventStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockHandler.currentState).thenReturn(SessionState.initial());
    when(() => mockHandler.resetGameSession()).thenReturn(null);
    when(() => mockHandler.joinMatchmaking()).thenReturn(null);
    when(() => mockHandler.cancelMatchmaking()).thenReturn(null);
  });

  group('MatchmakingBloc', () {
    test('initial state is correct', () {
      final bloc = MatchmakingBloc(handler: mockHandler);
      expect(bloc.state, equals(const MatchmakingState()));
      bloc.close();
    });

    test('handler getter exposes the WebSocket handler', () {
      final bloc = MatchmakingBloc(handler: mockHandler);
      expect(bloc.handler, equals(mockHandler));
      bloc.close();
    });

    group('StartMatchmaking', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'emits connecting state when already connected',
        build: () {
          when(
            () => mockHandler.connectionStatus,
          ).thenReturn(ConnectionStatus.connected);
          return MatchmakingBloc(handler: mockHandler);
        },
        act: (bloc) => bloc.add(StartMatchmaking()),
        expect: () => [
          const MatchmakingState(
            isConnecting: true,
            connectionStatus: ConnectionStatus.connected,
          ),
          const MatchmakingState(
            isConnecting: false,
            connectionStatus: ConnectionStatus.connected,
          ),
        ],
        verify: (_) {
          verify(() => mockHandler.resetGameSession()).called(1);
          verify(() => mockHandler.joinMatchmaking()).called(1);
        },
      );

      blocTest<MatchmakingBloc, MatchmakingState>(
        'does nothing if already connecting',
        build: () => MatchmakingBloc(handler: mockHandler),
        seed: () => const MatchmakingState(isConnecting: true),
        act: (bloc) => bloc.add(StartMatchmaking()),
        expect: () => [],
      );
    });

    group('UpdateParticipants', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'updates participants list',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) {
          final participants = [
            Participant(
              id: '1',
              name: 'Player 1',
              unitCount: 5,
              isMe: true,
              isActive: true,
            ),
            Participant(
              id: '2',
              name: 'Player 2',
              unitCount: 5,
              isMe: false,
              isActive: true,
            ),
          ];
          bloc.add(UpdateParticipants(participants));
        },
        expect: () => [
          isA<MatchmakingState>().having(
            (s) => s.participants.length,
            'participants length',
            2,
          ),
        ],
      );
    });

    group('UpdateConnectionStatus', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'updates connection status',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) =>
            bloc.add(const UpdateConnectionStatus(ConnectionStatus.connected)),
        expect: () => [
          const MatchmakingState(connectionStatus: ConnectionStatus.connected),
        ],
      );

      blocTest<MatchmakingBloc, MatchmakingState>(
        'transitions through multiple connection states',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) {
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.connecting));
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.connected));
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.reconnecting));
        },
        expect: () => [
          const MatchmakingState(connectionStatus: ConnectionStatus.connecting),
          const MatchmakingState(connectionStatus: ConnectionStatus.connected),
          const MatchmakingState(
            connectionStatus: ConnectionStatus.reconnecting,
          ),
        ],
      );
    });

    group('UpdateTimer', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'updates seconds remaining',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) => bloc.add(const UpdateTimer(45)),
        expect: () => [const MatchmakingState(secondsRemaining: 45)],
      );

      blocTest<MatchmakingBloc, MatchmakingState>(
        'counts down timer',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) {
          bloc.add(const UpdateTimer(60));
          bloc.add(const UpdateTimer(59));
          bloc.add(const UpdateTimer(58));
        },
        expect: () => [
          const MatchmakingState(secondsRemaining: 60),
          const MatchmakingState(secondsRemaining: 59),
          const MatchmakingState(secondsRemaining: 58),
        ],
      );
    });

    group('MatchFound', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'sets match found flag',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) => bloc.add(MatchFound()),
        expect: () => [const MatchmakingState(isMatchFound: true)],
      );
    });

    group('TriggerError', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'sets error message',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) => bloc.add(const TriggerError('Connection failed')),
        expect: () => [const MatchmakingState(error: 'Connection failed')],
      );
    });

    group('CancelMatchmaking', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'resets to initial state and cancels matchmaking',
        build: () => MatchmakingBloc(handler: mockHandler),
        seed: () => const MatchmakingState(
          participants: [],
          connectionStatus: ConnectionStatus.connected,
          secondsRemaining: 30,
        ),
        act: (bloc) => bloc.add(CancelMatchmaking()),
        expect: () => [const MatchmakingState()],
        verify: (_) {
          verify(() => mockHandler.cancelMatchmaking()).called(1);
        },
      );
    });

    group('SyncLobbyCreatedAt', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'syncs lobby creation timestamp',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) => bloc.add(const SyncLobbyCreatedAt(1234567890)),
        expect: () => [],
        verify: (bloc) {
          // Timer should be started but state doesn't change immediately
          expect(bloc.state.secondsRemaining, 60);
        },
      );
    });

    group('State Transitions', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'complete matchmaking flow',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) {
          // Start matchmaking
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.connecting));
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.connected));

          // Add participants
          bloc.add(
            UpdateParticipants([
              Participant(
                id: '1',
                name: 'Me',
                unitCount: 5,
                isMe: true,
                isActive: true,
              ),
            ]),
          );

          // Timer countdown (skip 60 as it's the default)
          bloc.add(const UpdateTimer(45));

          // Match found
          bloc.add(MatchFound());
        },
        expect: () => [
          const MatchmakingState(connectionStatus: ConnectionStatus.connecting),
          const MatchmakingState(connectionStatus: ConnectionStatus.connected),
          isA<MatchmakingState>()
              .having((s) => s.participants.length, 'participants', 1)
              .having(
                (s) => s.connectionStatus,
                'status',
                ConnectionStatus.connected,
              ),
          isA<MatchmakingState>()
              .having((s) => s.secondsRemaining, 'seconds', 45)
              .having((s) => s.participants.length, 'participants', 1),
          isA<MatchmakingState>()
              .having((s) => s.isMatchFound, 'match found', true)
              .having((s) => s.participants.length, 'participants', 1),
        ],
      );
    });

    group('Error Handling', () {
      blocTest<MatchmakingBloc, MatchmakingState>(
        'handles connection errors gracefully',
        build: () => MatchmakingBloc(handler: mockHandler),
        act: (bloc) {
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.connecting));
          bloc.add(const TriggerError('Network timeout'));
          bloc.add(const UpdateConnectionStatus(ConnectionStatus.disconnected));
        },
        expect: () => [
          const MatchmakingState(connectionStatus: ConnectionStatus.connecting),
          const MatchmakingState(
            connectionStatus: ConnectionStatus.connecting,
            error: 'Network timeout',
          ),
          // Error is cleared when connection status updates
          const MatchmakingState(
            connectionStatus: ConnectionStatus.disconnected,
          ),
        ],
      );
    });

    group('Cleanup', () {
      test('closes all subscriptions on dispose', () async {
        final bloc = MatchmakingBloc(handler: mockHandler);
        await bloc.close();

        // Verify bloc is closed
        expect(bloc.isClosed, true);
      });
    });
  });
}
