import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/features/session/bloc/session_bloc.dart';
import 'package:veil_core/features/session/bloc/session_event.dart';
import 'package:veil_core/features/session/bloc/session_state.dart';
import 'package:veil_core/features/session/logic/game_session_handler.dart';
import 'package:veil_core/features/session/models/session_enums.dart';
import 'package:veil_core/features/session/models/session_state.dart' as model;
import 'package:veil_core/features/session/models/unit.dart';

class MockGameSessionHandler extends Mock implements GameSessionHandler {}

void main() {
  late MockGameSessionHandler mockHandler;
  late StreamController<model.SessionState> stateController;
  late StreamController<SessionEventType> eventController;

  setUp(() {
    mockHandler = MockGameSessionHandler();
    stateController = StreamController<model.SessionState>.broadcast();
    eventController = StreamController<SessionEventType>.broadcast();

    when(
      () => mockHandler.sessionStateStream,
    ).thenAnswer((_) => stateController.stream);
    when(
      () => mockHandler.eventStream,
    ).thenAnswer((_) => eventController.stream);
    when(() => mockHandler.activeEventActorId).thenReturn(null);
    when(() => mockHandler.lastCountClaimed).thenReturn(0);
    when(() => mockHandler.dispose()).thenAnswer((_) async {});
  });

  tearDown(() {
    stateController.close();
    eventController.close();
  });

  group('SessionBloc', () {
    test('initial state is correct', () {
      final bloc = SessionBloc(handler: mockHandler);
      expect(bloc.state, SessionBlocState.initial());
      bloc.close();
    });

    blocTest<SessionBloc, SessionBlocState>(
      'emits updated engine state when EngineStateUpdated is added',
      build: () => SessionBloc(handler: mockHandler),
      act: (bloc) {
        final newState = model.SessionState.initial().copyWith(roomId: '999');
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
      seed: () => SessionBlocState.initial().copyWith(isSelectingRank: true),
      act: (bloc) => bloc.add(const RankStaged(UnitRank.ace)),
      expect: () => [
        isA<SessionBlocState>()
            .having((s) => s.stagedRank, 'stagedRank', UnitRank.ace)
            .having((s) => s.isSelectingRank, 'isSelectingRank', false),
      ],
    );

    blocTest<SessionBloc, SessionBlocState>(
      'toggles rank selection when RankSelectionToggleRequested is added',
      build: () => SessionBloc(handler: mockHandler),
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
      build: () => SessionBloc(handler: mockHandler),
      act: (bloc) {
        when(() => mockHandler.activeEventActorId).thenReturn('p1');
        when(() => mockHandler.lastCountClaimed).thenReturn(3);
        eventController.add(SessionEventType.cardsPlayed);
      },
      expect: () => [
        isA<SessionBlocState>()
            .having(
              (s) => s.lastEvent,
              'lastEvent',
              SessionEventType.cardsPlayed,
            )
            .having((s) => s.lastEventActorId, 'actorId', 'p1')
            .having((s) => s.lastEventCardCount, 'cardCount', 3),
      ],
    );
  });
}
