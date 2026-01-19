import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../../core/services/system_status_service.dart';
import '../../../../core/services/audio/audio_service_interface.dart';
import '../../../../core/services/services.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/constants/sound_assets.dart';
import '../../../../core/engine/domain/models/session_state.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WebSocketSessionHandler _sessionHandler;
  final SystemStatusService _systemStatusService;
  final AudioService _audioService;
  final GreetingService _greetingService;
  late StreamSubscription _statusSubscription;
  late StreamSubscription _sessionSubscription;

  HomeBloc({
    required WebSocketSessionHandler sessionHandler,
    required SystemStatusService systemStatusService,
    required AudioService audioService,
    required GreetingService greetingService,
  }) : _sessionHandler = sessionHandler,
       _systemStatusService = systemStatusService,
       _audioService = audioService,
       _greetingService = greetingService,
       super(
         HomeState(
           systemStatus: systemStatusService.currentStatus,
           hasActiveSession: _checkActiveSession(
             sessionHandler.currentSessionState,
           ),
           greeting: greetingService.getTimeBasedGreeting(),
         ),
       ) {
    // Event Handlers
    on<HomeStarted>(_onHomeStarted);
    on<HomePlayOnlineClicked>(_onPlayOnlineClicked);
    on<HomeRejoinGameConfirmed>(_onRejoinGameConfirmed);
    on<HomeNewGameConfirmed>(_onNewGameConfirmed);
    on<HomeCreateRoomClicked>(_onCreateRoomClicked);
    on<HomeCreateHotspotClicked>(_onCreateHotspotClicked);
    on<HomeJoinHotspotClicked>(_onJoinHotspotClicked);
    on<HomeJoinRoomClicked>(_onJoinRoomClicked);
    on<HomeBotMatchClicked>(_onBotMatchClicked);
    on<HomeFriendsMatchClicked>(_onFriendsMatchClicked);
    on<HomeDailyChallengeClicked>(_onDailyChallengeClicked);
    on<HomeBottomNavTapped>(_onBottomNavTapped);
    on<HomeRefillCoinsClicked>(_onRefillCoinsClicked);
    on<HomeSystemStatusChanged>(_onSystemStatusChanged);
    on<HomeSessionStateChanged>(_onSessionStateChanged);

    // Subscribe to System Status
    _statusSubscription = _systemStatusService.statusStream.listen((status) {
      add(HomeSystemStatusChanged(status));
    });

    // Subscribe to Session Updates
    _sessionSubscription = _sessionHandler.sessionStateStream.listen((session) {
      add(HomeSessionStateChanged(_checkActiveSession(session)));
    });
  }

  static bool _checkActiveSession(SessionState session) {
    return session.roomId != '0' && session.roomId != '000';
  }

  @override
  Future<void> close() {
    _statusSubscription.cancel();
    _sessionSubscription.cancel();
    return super.close();
  }

  // Helper to emit effect and then clear it
  void _emitEffect(Emitter<HomeState> emit, HomeSideEffect effect) {
    emit(state.copyWith(effect: effect));
    // Clear the effect immediately so it doesn't re-trigger or stick around
    emit(state.copyWith(effect: null));
  }

  Future<void> _onHomeStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    // Update greeting just in case it's stale
    emit(state.copyWith(greeting: _greetingService.getTimeBasedGreeting()));

    // Start Lobby Music
    if (_audioService.isInitialized) {
      _audioService.playBgm(SoundAssets.lobbyAmbience);
    } else {
      AppLogger.warning(
        'AudioService not initialized yet. Skipping auto-play.',
      );
    }
  }

  Future<void> _onPlayOnlineClicked(
    HomePlayOnlineClicked event,
    Emitter<HomeState> emit,
  ) async {
    // Check for active session
    if (state.hasActiveSession) {
      _emitEffect(emit, HomeShowRejoinDialog());
      return;
    }

    // Check Coin Balance
    final coins = event.stats?.coins ?? 0;
    if (coins < 100) {
      _emitEffect(emit, HomeShowInsufficientCoinsDialog());
      return;
    }

    _emitEffect(emit, HomeNavigateTo('/matchmaking'));
  }

  Future<void> _onRejoinGameConfirmed(
    HomeRejoinGameConfirmed event,
    Emitter<HomeState> emit,
  ) async {
    _emitEffect(emit, HomeNavigateTo('/matchmaking'));
  }

  Future<void> _onNewGameConfirmed(
    HomeNewGameConfirmed event,
    Emitter<HomeState> emit,
  ) async {
    _sessionHandler.leaveRoom('');
    _sessionHandler.resetGameSession();
    _emitEffect(emit, HomeNavigateTo('/matchmaking'));
  }

  Future<void> _onCreateRoomClicked(
    HomeCreateRoomClicked event,
    Emitter<HomeState> emit,
  ) async {
    if (FeatureFlags.enablePrivateRooms) {
      _emitEffect(emit, HomeNavigateTo('/create_room'));
    } else {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Private Rooms',
          description:
              'Create a private room to host exclusive matches with invited players.',
          icon: Icons.add_circle_outline,
        ),
      );
    }
  }

  Future<void> _onCreateHotspotClicked(
    HomeCreateHotspotClicked event,
    Emitter<HomeState> emit,
  ) async {
    _emitEffect(
      emit,
      HomeShowComingSoonDialog(
        featureName: 'Create Hotspot',
        description:
            'Host a local offline game via Wi-Fi Hotspot for nearby friends to join.',
        icon: Icons.wifi_tethering,
      ),
    );
  }

  Future<void> _onJoinHotspotClicked(
    HomeJoinHotspotClicked event,
    Emitter<HomeState> emit,
  ) async {
    _emitEffect(
      emit,
      HomeShowComingSoonDialog(
        featureName: 'Join Hotspot',
        description: 'Join a nearby friend\'s offline Hotspot game.',
        icon: Icons
            .wifi_find_outlined, // Using a different icon for scanning/joining
      ),
    );
  }

  Future<void> _onJoinRoomClicked(
    HomeJoinRoomClicked event,
    Emitter<HomeState> emit,
  ) async {
    if (FeatureFlags.enablePrivateRooms) {
      _emitEffect(emit, HomeNavigateTo('/join_room'));
    } else {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Private Rooms',
          description:
              'Join a private room to participate in exclusive matches.',
          icon: Icons.login,
        ),
      );
    }
  }

  Future<void> _onBotMatchClicked(
    HomeBotMatchClicked event,
    Emitter<HomeState> emit,
  ) async {
    if (FeatureFlags.enableBotPlayers) {
      // Navigate to Matchmaking (Fake Online Mode)
      _emitEffect(emit, HomeNavigateTo('/matchmaking'));
    } else {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Bot Match',
          description:
              'Practice your bluffing skills against intelligent AI opponents.',
          icon: Icons.smart_toy_outlined,
        ),
      );
    }
  }

  Future<void> _onFriendsMatchClicked(
    HomeFriendsMatchClicked event,
    Emitter<HomeState> emit,
  ) async {
    if (FeatureFlags.enableFriendsMatchOffline) {
      _emitEffect(emit, HomeNavigateTo(AppRouter.offlineLobby));
    } else if (FeatureFlags.enableFriendsMatch) {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Online Friends Match',
          description: 'Play with your friends online anywhere in the world.',
          icon: Icons.public,
        ),
      );
    } else {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Friends Match',
          description:
              'Play with friends locally or online. Challenge them to a battle of wit!',
          icon: Icons.people_outline,
        ),
      );
    }
  }

  Future<void> _onDailyChallengeClicked(
    HomeDailyChallengeClicked event,
    Emitter<HomeState> emit,
  ) async {
    if (FeatureFlags.enableDailyChallenges) {
      _emitEffect(emit, HomeNavigateTo('/challenges'));
    } else {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Daily Challenges',
          description:
              'Complete daily challenges to earn rewards and climb the leaderboard!',
          icon: Icons.track_changes,
        ),
      );
    }
  }

  Future<void> _onBottomNavTapped(
    HomeBottomNavTapped event,
    Emitter<HomeState> emit,
  ) async {
    // Logic checks
    if (event.index == 1 && !FeatureFlags.enableInnerCircle) {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Inner Circle',
          description:
              'Connect with your close friends and track your group play.',
          icon: Icons.people_outline,
        ),
      );
      return;
    }
    if (event.index == 2 && !FeatureFlags.enableGlobalRankings) {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Global Rankings',
          description:
              'See where you stand against the best players world-wide.',
          icon: Icons.emoji_events_outlined,
        ),
      );
      return;
    }
    if (event.index == 3 && !FeatureFlags.enableEliteDecks) {
      _emitEffect(
        emit,
        HomeShowComingSoonDialog(
          featureName: 'Elite Deck Collection',
          description: 'Explore and collect unique decks and cards.',
          icon: Icons.shopping_bag_outlined,
        ),
      );
      return;
    }

    // Update Tab
    emit(state.copyWith(tabIndex: event.index));
  }

  Future<void> _onRefillCoinsClicked(
    HomeRefillCoinsClicked event,
    Emitter<HomeState> emit,
  ) async {
    _sessionHandler.refillCoins();
    _emitEffect(emit, HomeShowSnackBar('Refilling coins...'));
  }

  Future<void> _onSystemStatusChanged(
    HomeSystemStatusChanged event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(systemStatus: event.status));
  }

  Future<void> _onSessionStateChanged(
    HomeSessionStateChanged event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(hasActiveSession: event.hasActiveSession));
  }
}
