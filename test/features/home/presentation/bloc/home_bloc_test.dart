import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/features/home/presentation/bloc/home_bloc.dart';
import 'package:veil_core/features/home/presentation/bloc/home_event.dart';
import 'package:veil_core/features/home/presentation/bloc/home_state.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';
import 'package:veil_core/core/services/system_status_service.dart';
import 'package:veil_core/core/models/system_status.dart';
import 'package:veil_core/features/auth/domain/models/user_stats.dart';
import 'package:veil_core/core/engine/domain/models/session_state.dart';
import 'package:veil_core/core/services/audio/audio_service_interface.dart';
import 'package:veil_core/core/constants/sound_assets.dart';
import 'package:veil_core/core/services/services.dart';

class MockWebSocketSessionHandler extends Mock
    implements WebSocketSessionHandler {}

class MockSystemStatusService extends Mock implements SystemStatusService {}

class MockAudioService extends Mock implements AudioService {}

class MockGreetingService extends Mock implements GreetingService {}

void main() {
  late MockWebSocketSessionHandler mockSessionHandler;
  late MockSystemStatusService mockStatusService;
  late MockAudioService mockAudioService;
  late MockGreetingService mockGreetingService;
  late StreamController<SystemStatus> statusController;
  late StreamController<SessionState> sessionController;

  setUp(() {
    mockSessionHandler = MockWebSocketSessionHandler();
    mockStatusService = MockSystemStatusService();
    mockAudioService = MockAudioService();
    mockGreetingService = MockGreetingService();
    statusController = StreamController<SystemStatus>.broadcast();
    sessionController = StreamController<SessionState>.broadcast();

    when(
      () => mockStatusService.statusStream,
    ).thenAnswer((_) => statusController.stream);
    when(
      () => mockStatusService.currentStatus,
    ).thenReturn(SystemStatus.healthy());

    when(
      () => mockSessionHandler.sessionStateStream,
    ).thenAnswer((_) => sessionController.stream);
    when(
      () => mockSessionHandler.currentSessionState,
    ).thenReturn(SessionState.initial());

    when(
      () => mockGreetingService.getTimeBasedGreeting(),
    ).thenReturn('Good Morning');

    // Default audio stubs
    when(() => mockAudioService.isInitialized).thenReturn(true);
    when(() => mockAudioService.playBgm(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    statusController.close();
    sessionController.close();
  });

  group('HomeBloc', () {
    test('initial state contains default system status and greeting', () {
      final bloc = HomeBloc(
        sessionHandler: mockSessionHandler,
        systemStatusService: mockStatusService,
        audioService: mockAudioService,
        greetingService: mockGreetingService,
      );
      expect(bloc.state.systemStatus, equals(SystemStatus.healthy()));
      expect(bloc.state.greeting, equals('Good Morning'));
      bloc.close();
    });

    blocTest<HomeBloc, HomeState>(
      'plays lobby music on HomeStarted if initialized',
      build: () => HomeBloc(
        sessionHandler: mockSessionHandler,
        systemStatusService: mockStatusService,
        audioService: mockAudioService,
        greetingService: mockGreetingService,
      ),
      act: (bloc) => bloc.add(HomeStarted()),
      verify: (_) {
        verify(
          () => mockAudioService.playBgm(SoundAssets.lobbyAmbience),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'updates greeting on HomeStarted',
      build: () {
        when(
          () => mockGreetingService.getTimeBasedGreeting(),
        ).thenReturn('Initial');
        return HomeBloc(
          sessionHandler: mockSessionHandler,
          systemStatusService: mockStatusService,
          audioService: mockAudioService,
          greetingService: mockGreetingService,
        );
      },
      act: (bloc) {
        when(
          () => mockGreetingService.getTimeBasedGreeting(),
        ).thenReturn('Updated');
        bloc.add(HomeStarted());
      },
      expect: () => [
        isA<HomeState>().having((s) => s.greeting, 'greeting', 'Updated'),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits updated system status when HomeSystemStatusChanged (via stream) occurs',
      build: () => HomeBloc(
        sessionHandler: mockSessionHandler,
        systemStatusService: mockStatusService,
        audioService: mockAudioService,
        greetingService: mockGreetingService,
      ),
      act: (_) => statusController.add(SystemStatus.noInternet()),
      expect: () => [
        isA<HomeState>().having(
          (s) => s.systemStatus.type,
          'status type',
          SystemStatusType.noInternet,
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits hasActiveSession when session data updates',
      build: () => HomeBloc(
        sessionHandler: mockSessionHandler,
        systemStatusService: mockStatusService,
        audioService: mockAudioService,
        greetingService: mockGreetingService,
      ),
      act: (_) =>
          sessionController.add(SessionState.initial().copyWith(roomId: '123')),
      expect: () => [
        isA<HomeState>().having(
          (s) => s.hasActiveSession,
          'hasActiveSession',
          true,
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'Logic: Refill coins triggers handler and emits snackbar',
      build: () => HomeBloc(
        sessionHandler: mockSessionHandler,
        systemStatusService: mockStatusService,
        audioService: mockAudioService,
        greetingService: mockGreetingService,
      ),
      act: (bloc) => bloc.add(HomeRefillCoinsClicked()),
      verify: (_) {
        verify(() => mockSessionHandler.refillCoins()).called(1);
      },
      expect: () => [
        isA<HomeState>().having(
          (s) => s.effect,
          'effect',
          isA<HomeShowSnackBar>(),
        ),
        isA<HomeState>().having((s) => s.effect, 'effect', isNull),
      ],
    );

    group('HomePlayOnlineClicked', () {
      final statsLowCoins = UserStats(
        userId: '1',
        name: 'User',
        coins: 50,
        rank: 'Novice',
        wins: 0,
        losses: 0,
      );
      final statsOkCoins = UserStats(
        userId: '1',
        name: 'User',
        coins: 150,
        rank: 'Novice',
        wins: 0,
        losses: 0,
      );

      blocTest<HomeBloc, HomeState>(
        'shows insufficient coins dialog if coins < 100',
        build: () {
          when(
            () => mockSessionHandler.currentSessionState,
          ).thenReturn(SessionState.initial());
          return HomeBloc(
            sessionHandler: mockSessionHandler,
            systemStatusService: mockStatusService,
            audioService: mockAudioService,
            greetingService: mockGreetingService,
          );
        },
        act: (bloc) => bloc.add(HomePlayOnlineClicked(statsLowCoins)),
        expect: () => [
          isA<HomeState>().having(
            (s) => s.effect,
            'effect',
            isA<HomeShowInsufficientCoinsDialog>(),
          ),
          isA<HomeState>().having((s) => s.effect, 'effect', isNull),
        ],
      );

      blocTest<HomeBloc, HomeState>(
        'shows rejoin dialog if state.hasActiveSession is true',
        build: () {
          // Initialize with active session
          when(
            () => mockSessionHandler.currentSessionState,
          ).thenReturn(SessionState.initial().copyWith(roomId: '123'));
          return HomeBloc(
            sessionHandler: mockSessionHandler,
            systemStatusService: mockStatusService,
            audioService: mockAudioService,
            greetingService: mockGreetingService,
          );
        },
        act: (bloc) => bloc.add(HomePlayOnlineClicked(statsOkCoins)),
        expect: () => [
          isA<HomeState>().having(
            (s) => s.effect,
            'effect',
            isA<HomeShowRejoinDialog>(),
          ),
          isA<HomeState>().having((s) => s.effect, 'effect', isNull),
        ],
      );

      blocTest<HomeBloc, HomeState>(
        'navigates to matchmaking if coins ok and no active game',
        build: () {
          when(
            () => mockSessionHandler.currentSessionState,
          ).thenReturn(SessionState.initial());
          return HomeBloc(
            sessionHandler: mockSessionHandler,
            systemStatusService: mockStatusService,
            audioService: mockAudioService,
            greetingService: mockGreetingService,
          );
        },
        act: (bloc) => bloc.add(HomePlayOnlineClicked(statsOkCoins)),
        expect: () => [
          isA<HomeState>().having(
            (s) => s.effect,
            'effect',
            isA<HomeNavigateTo>().having(
              (e) => e.route,
              'route',
              '/matchmaking',
            ),
          ),
          isA<HomeState>().having((s) => s.effect, 'effect', isNull),
        ],
      );
    });
  });
}
