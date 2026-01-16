import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veil_core/core/utils/app_logger.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../../core/engine/domain/models/room_event.dart';
import 'matchmaking_event.dart';
import 'matchmaking_state.dart';

class MatchmakingBloc extends Bloc<MatchmakingEvent, MatchmakingState> {
  final WebSocketSessionHandler _handler;
  StreamSubscription? _statsSubscription;
  StreamSubscription? _sessionStateSubscription;
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _roomEventSubscription;
  Timer? _waitTimer;
  Timer? _timeoutTimer;
  int _lobbyCreatedAt = 0;

  MatchmakingBloc({WebSocketSessionHandler? handler})
    : _handler = handler ?? sl.webSocketSessionHandler,
      super(const MatchmakingState()) {
    on<StartMatchmaking>(_onStartMatchmaking);
    on<UpdateParticipants>(_onUpdateParticipants);
    on<UpdateConnectionStatus>(_onUpdateConnectionStatus);
    on<UpdateTimer>(_onUpdateTimer);
    on<MatchFound>(_onMatchFound);
    on<CancelMatchmaking>(_onCancelMatchmaking);
    on<TriggerError>(_onTriggerError);
    on<SyncLobbyCreatedAt>(_onSyncLobbyCreatedAt);
  }

  // Public getter to expose handler for SessionBloc integration
  WebSocketSessionHandler get handler => _handler;

  Future<void> _onStartMatchmaking(
    StartMatchmaking event,
    Emitter<MatchmakingState> emit,
  ) async {
    if (state.isConnecting) {
      AppLogger.info(
        '🎯 [MatchmakingBloc] Already connecting, ignoring StartMatchmaking',
      );
      return;
    }

    AppLogger.info('🚀 [MatchmakingBloc] Starting matchmaking...');

    emit(
      state.copyWith(
        isConnecting: true,
        connectionStatus: _handler.connectionStatus,
      ),
    );

    try {
      if (_handler.connectionStatus != ConnectionStatus.connected) {
        AppLogger.info(
          '🔌 [MatchmakingBloc] Not connected, attempting connection...',
        );
        final user = FirebaseAuth.instance.currentUser;
        final token = user != null
            ? await user.getIdToken()
            : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

        int retries = 0;
        while (retries < 3) {
          try {
            await _handler.connect(
              AppConfig.instance.serverUrl,
              token!,
              displayName: user?.displayName,
            );
            if (_handler.connectionStatus == ConnectionStatus.connected) {
              AppLogger.info('✅ [MatchmakingBloc] Connection successful');
              break;
            }
          } catch (e) {
            AppLogger.warning(
              '⚠️ [MatchmakingBloc] Connection attempt ${retries + 1} failed',
              data: {'error': e.toString()},
            );
            retries++;
            if (retries >= 3) rethrow;
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      }

      _handler.resetGameSession();
      AppLogger.info('🔄 [MatchmakingBloc] Game session reset');

      _setupSubscriptions();

      if (_handler.connectionStatus == ConnectionStatus.connected) {
        AppLogger.info('🎲 [MatchmakingBloc] Joining matchmaking queue...');
        _handler.joinMatchmaking();
        _startTimeoutTimer();
      }

      emit(state.copyWith(isConnecting: false));
    } catch (e) {
      AppLogger.error(
        '❌ [MatchmakingBloc] Error during matchmaking start',
        exception: e,
      );
      emit(state.copyWith(isConnecting: false, error: e.toString()));
    }
  }

  void _setupSubscriptions() {
    AppLogger.info('📡 [MatchmakingBloc] Setting up stream subscriptions...');

    _statsSubscription?.cancel();
    _sessionStateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _roomEventSubscription?.cancel();

    _statsSubscription = _handler.statsStream.listen((stats) {
      // Stats handled by AuthBloc usually, but we could add to state if needed
    });

    _errorSubscription = _handler.errorStream.listen((failure) {
      AppLogger.warning(
        '⚠️ [MatchmakingBloc] Error received',
        data: {'message': failure.message},
      );
      add(TriggerError(failure.message));
    });

    _connectionStatusSubscription = _handler.connectionStatusStream.listen((
      status,
    ) {
      AppLogger.info('🔌 [MatchmakingBloc] Connection status changed: $status');
      add(UpdateConnectionStatus(status));
      if (status == ConnectionStatus.connected && !state.isMatchFound) {
        if (_handler.currentState.roomId == '000') {
          _handler.joinMatchmaking();
        }
      }
    });

    _sessionStateSubscription = _handler.sessionStateStream.listen((
      sessionState,
    ) {
      AppLogger.info(
        '📊 [MatchmakingBloc] Session state updated',
        data: {'participants': sessionState.participants.length},
      );
      add(UpdateParticipants(sessionState.participants));

      if (sessionState.createdAt != null &&
          _lobbyCreatedAt != sessionState.createdAt) {
        add(SyncLobbyCreatedAt(sessionState.createdAt!));
      }

      if (sessionState.currentPhase == SessionPhase.thinking &&
          !state.isMatchFound) {
        AppLogger.info(
          '🎉 [MatchmakingBloc] Match found! Transitioning to game...',
        );
        add(MatchFound());
      }
    });

    _roomEventSubscription = _handler.roomEventStream.listen((evt) {
      int? newCreatedAt;
      if (evt is RoomCreated) {
        newCreatedAt = evt.createdAt;
      } else if (evt is RoomJoined) {
        newCreatedAt = evt.createdAt;
      } else if (evt is RoomUpdated) {
        newCreatedAt = evt.createdAt;
        if (evt.participants.isNotEmpty) {
          add(UpdateParticipants(evt.participants));
        }
      }

      if (newCreatedAt != null) {
        final normalized = newCreatedAt > 2000000000
            ? newCreatedAt ~/ 1000
            : newCreatedAt;
        if (_lobbyCreatedAt != normalized) {
          add(SyncLobbyCreatedAt(normalized));
        }
      }
    });
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!state.isMatchFound) {
        // Maybe handle 45s timeout specific log or event
      }
    });
  }

  void _onSyncLobbyCreatedAt(
    SyncLobbyCreatedAt event,
    Emitter<MatchmakingState> emit,
  ) {
    _lobbyCreatedAt = event.createdAt;
    _startLobbyTimer();
  }

  void _startLobbyTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final elapsed = (now - _lobbyCreatedAt).clamp(0, 600);
      int remaining = 60 - elapsed;
      if (remaining < 0) remaining = 0;

      add(UpdateTimer(remaining));

      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  void _onUpdateParticipants(
    UpdateParticipants event,
    Emitter<MatchmakingState> emit,
  ) {
    AppLogger.info(
      '👥 [MatchmakingBloc] Participants updated',
      data: {'count': event.participants.length},
    );
    emit(state.copyWith(participants: event.participants));
  }

  void _onUpdateConnectionStatus(
    UpdateConnectionStatus event,
    Emitter<MatchmakingState> emit,
  ) {
    emit(state.copyWith(connectionStatus: event.status));
  }

  void _onUpdateTimer(UpdateTimer event, Emitter<MatchmakingState> emit) {
    emit(state.copyWith(secondsRemaining: event.secondsRemaining));
  }

  void _onMatchFound(MatchFound event, Emitter<MatchmakingState> emit) {
    AppLogger.info('✅ [MatchmakingBloc] Match found, canceling timers');
    _timeoutTimer?.cancel();
    _waitTimer?.cancel();
    emit(state.copyWith(isMatchFound: true));
  }

  void _onTriggerError(TriggerError event, Emitter<MatchmakingState> emit) {
    emit(state.copyWith(error: event.message));
  }

  void _onCancelMatchmaking(
    CancelMatchmaking event,
    Emitter<MatchmakingState> emit,
  ) {
    AppLogger.info('🛑 [MatchmakingBloc] Matchmaking canceled');
    _handler.cancelMatchmaking();
    emit(const MatchmakingState());
  }

  @override
  Future<void> close() {
    _statsSubscription?.cancel();
    _sessionStateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _roomEventSubscription?.cancel();
    _waitTimer?.cancel();
    _timeoutTimer?.cancel();
    return super.close();
  }
}
