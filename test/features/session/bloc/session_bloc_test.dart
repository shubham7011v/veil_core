import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/features/session/session.dart';
import 'package:veil_core/core/engine/engine.dart' as engine;
import 'package:veil_core/core/error/failure.dart';

class MockGameSessionHandler extends Mock
    implements engine.GameSessionHandler {}

void main() {
  late MockGameSessionHandler mockHandler;
  late StreamController<engine.SessionState> stateController;
  late StreamController<engine.SessionEventType> eventController;
  late StreamController<Map<String, dynamic>> chatController;
  late StreamController<Failure> errorController;

  setUp(() {
    mockHandler = MockGameSessionHandler();
    stateController = StreamController<engine.SessionState>.broadcast();
    eventController = StreamController<engine.SessionEventType>.broadcast();
    chatController = StreamController<Map<String, dynamic>>.broadcast();
    errorController = StreamController<Failure>.broadcast();

    when(
      () => mockHandler.sessionStateStream,
    ).thenAnswer((_) => stateController.stream);
    when(
      () => mockHandler.eventStream,
    ).thenAnswer((_) => eventController.stream);
    when(() => mockHandler.chatStream).thenAnswer((_) => chatController.stream);
    when(
      () => mockHandler.errorStream,
    ).thenAnswer((_) => errorController.stream);
    when(() => mockHandler.typingStatus).thenReturn({});
    when(() => mockHandler.lastMove).thenReturn(null);
    when(() => mockHandler.isRevealingBluff).thenReturn(false);
    when(() => mockHandler.pNames).thenReturn({'me': 'You'});
    when(() => mockHandler.gameLog).thenReturn([]);
    when(() => mockHandler.activeEventActorId).thenReturn(null);
    when(() => mockHandler.lastCountClaimed).thenReturn(0);
    when(
      () => mockHandler.currentState,
    ).thenReturn(engine.SessionState.initial());
    when(
      () => mockHandler.lastEventType,
    ).thenReturn(engine.SessionEventType.none);
    when(() => mockHandler.lastEventTimestamp).thenReturn(0);
    when(() => mockHandler.dispose()).thenAnswer((_) async {});
  });

  tearDown(() {
    stateController.close();
    eventController.close();
    chatController.close();
    errorController.close();
  });

  group('SessionBloc', () {
    test('initial state is correct', () {
      final bloc = SessionBloc(handler: mockHandler);
      expect(bloc.state.engineState, engine.SessionState.initial());
      bloc.close();
    });

    blocTest<SessionBloc, SessionBlocState>(
      'emits updated engine state when EngineStateUpdated is added',
      build: () => SessionBloc(handler: mockHandler),
      skip: 1,
      act: (bloc) {
        final newState = engine.SessionState.initial().copyWith(roomId: '999');
        stateController.add(newState);
      },
      expect: () => [
        isA<SessionBlocState>().having(
          (s) => s.engineState.roomId,
          'roomId',
          '999',
        ),
      ],
    );

    blocTest<SessionBloc, SessionBlocState>(
      'toggles unit selection when UnitToggled is added',
      build: () => SessionBloc(handler: mockHandler),
      skip: 1,
      act: (bloc) => bloc.add(const UnitToggled('u1')),
      expect: () => [
        isA<SessionBlocState>().having(
          (s) => s.selectedUnitIds,
          'selectedUnitIds',
          ['u1'],
        ),
      ],
    );

    blocTest<SessionBloc, SessionBlocState>(
      'removes unit if already selected in UnitToggled',
      build: () => SessionBloc(handler: mockHandler),
      skip: 1,
      seed: () =>
          SessionBlocState.initial().copyWith(selectedUnitIds: ['u1', 'u2']),
      act: (bloc) => bloc.add(const UnitToggled('u1')),
      expect: () => [
        isA<SessionBlocState>().having(
          (s) => s.selectedUnitIds,
          'selectedUnitIds',
          ['u2'],
        ),
      ],
    );

    blocTest<SessionBloc, SessionBlocState>(
      'sets staged rank and closes selector when RankStaged is added',
      build: () => SessionBloc(handler: mockHandler),
      skip: 1,
      seed: () => SessionBlocState.initial().copyWith(isSelectingRank: true),
      act: (bloc) => bloc.add(const RankStaged(engine.UnitRank.ace)),
      expect: () => [
        isA<SessionBlocState>()
            .having((s) => s.stagedRank, 'stagedRank', engine.UnitRank.ace)
            .having((s) => s.isSelectingRank, 'isSelectingRank', false),
      ],
    );

    blocTest<SessionBloc, SessionBlocState>(
      'toggles rank selection when RankSelectionToggleRequested is added',
      build: () => SessionBloc(handler: mockHandler),
      skip: 1,
      act: (bloc) => bloc.add(RankSelectionToggleRequested()),
      expect: () => [
        isA<SessionBlocState>().having(
          (s) => s.isSelectingRank,
          'isSelectingRank',
          true,
        ),
      ],
    );

    blocTest<SessionBloc, SessionBlocState>(
      'emits last event info when EngineEventReceived is added via handler stream',
      build: () {
        when(() => mockHandler.activeEventActorId).thenReturn('p1');
        when(() => mockHandler.lastCountClaimed).thenReturn(3);
        return SessionBloc(handler: mockHandler);
      },
      skip: 1,
      act: (bloc) => eventController.add(engine.SessionEventType.cardsPlayed),
      expect: () => [
        isA<SessionBlocState>()
            .having(
              (s) => s.lastEvent,
              'lastEvent',
              engine.SessionEventType.cardsPlayed,
            )
            .having((s) => s.lastEventActorId, 'actorId', 'p1')
            .having((s) => s.lastEventCardCount, 'cardCount', 3),
      ],
    );
  });
}
