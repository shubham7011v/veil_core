import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../../../../core/utils/app_logger.dart';
import 'session_event.dart';
import 'session_state.dart';
import '../../domain/models/match_stats.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';

class SessionBloc extends Bloc<SessionEvent, SessionBlocState> {
  engine.GameSessionHandler _handler;
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _chatSub;
  StreamSubscription? _errorSub;

  SessionBloc({engine.GameSessionHandler? handler})
    : _handler = handler ?? di.sl.gameSessionHandler,
      super(SessionBlocState.initial()) {
    // Action handlers
    on<SessionStartRequested>(_onStartRequested);
    on<UnitToggled>(_onUnitToggled);
    on<RankStaged>(_onRankStaged);
    on<RankSelectionToggleRequested>(_onRankSelectionToggle);
    on<CardsPlayRequested>(_onCardsPlayRequested);
    on<TurnPassRequested>(_onTurnPassRequested);
    on<ChallengeRaiseRequested>(_onChallengeRaiseRequested);
    on<HandSortRequested>(_onHandSortRequested);
    on<HandReorderRequested>(_onHandReorderRequested);
    on<HandlerSyncRequested>(_onHandlerSync);
    on<SessionResetRequested>(_onResetRequested);
    on<SessionHandlerSwapped>(_onHandlerSwapped);
    on<SessionErrorOccurred>(_onErrorOccurred);
    on<SessionErrorCleared>(_onErrorCleared);

    // Chat Event Handlers
    on<ChatStreamUpdated>(_onChatStreamUpdated);
    on<SendChatMessage>(_onSendChatMessage);
    on<SendEmojiMessage>(_onSendEmojiMessage);
    on<SendTypingStatus>(_onSendTypingStatus);
    on<TypingStatusChanged>(_onTypingStatusChanged);

    // Engine update handlers
    on<EngineStateUpdated>((event, emit) {
      final isNewRound = _handler.lastMove == null;
      final hasCards = event.state.myHand.isNotEmpty;
      final isNowMyTurn = event.state.activeParticipantId == 'me';
      final wasInRound = state.lastMove != null;

      // Detect round reset transition OR initial game start
      final roundJustReset = wasInRound && isNewRound;
      // Also check if we just joined/started (activeId check handles initial state)
      final gameJustStarted =
          state.engineState.activeParticipantId == '' && isNowMyTurn;

      // Show rank selector when: new round + my turn + have cards
      // Trigger when round just reset OR on initial game start
      final shouldShowRankSelector =
          isNewRound &&
          isNowMyTurn &&
          hasCards &&
          (roundJustReset || gameJustStarted);

      emit(
        state.copyWith(
          engineState: event.state,
          isRevealingBluff: _handler.isRevealingBluff,
          isBluffSuccessful: _handler.isBluffSuccessful, // Sync from handler
          lastMove: _handler.lastMove,
          clearLastMove: _handler.lastMove == null,
          pNames: _handler.pNames,
          gameLog: _handler.gameLog,
          // Clear stagedRank on round reset or game start, show selector
          clearStagedRank: shouldShowRankSelector,
          isSelectingRank: shouldShowRankSelector
              ? true
              : state.isSelectingRank,
        ),
      );
    });
    on<EngineEventReceived>((event, emit) {
      // Only sync lastMove if it's NOT null.
      // If it IS null (round reset), we wait for EngineStateUpdated to clear it.
      // This preserves state.lastMove so EngineStateUpdated can detect the transition
      // (wasInRound -> isNewRound) and trigger the rank selector auto-flip.
      final shouldSync = _handler.lastMove != null;

      // Track match statistics
      var updatedStats = state.matchStats;

      switch (event.type) {
        case engine.SessionEventType.cardsPlayed:
          updatedStats = updatedStats.copyWith(
            totalTurns: state.matchStats.totalTurns + 1,
            totalCardsPlayed:
                state.matchStats.totalCardsPlayed + event.cardCount,
          );
          break;
        case engine.SessionEventType.bluffCalled:
          updatedStats = updatedStats.copyWith(
            totalChallenges: state.matchStats.totalChallenges + 1,
          );
          break;
        case engine.SessionEventType.shuffling:
          // Game started, reset stats and record start time
          updatedStats = const MatchStats();
          emit(
            state.copyWith(
              lastEvent: event.type,
              lastEventActorId: event.actorId,
              lastEventCardCount: event.cardCount,
              lastEventTimestamp: DateTime.now().millisecondsSinceEpoch,
              isRevealingBluff: _handler.isRevealingBluff,
              isBluffSuccessful: _handler.isBluffSuccessful,
              gameLog: _handler.gameLog,
              lastMove: shouldSync ? _handler.lastMove : state.lastMove,
              clearLastMove: false,
              matchStats: updatedStats,
              gameStartTime: DateTime.now(),
            ),
          );
          return;
        default:
          break;
      }

      emit(
        state.copyWith(
          lastEvent: event.type,
          lastEventActorId: event.actorId,
          lastEventCardCount: event.cardCount,
          lastEventTimestamp: DateTime.now().millisecondsSinceEpoch,
          isRevealingBluff: _handler.isRevealingBluff,
          isBluffSuccessful: _handler.isBluffSuccessful,
          gameLog: _handler.gameLog,
          lastMove: shouldSync
              ? _handler.lastMove
              : state
                    .lastMove, // Preserve existing lastMove instead of clearing
          // IMPORTANT: Never clearLastMove here. Let EngineStateUpdated do it.
          clearLastMove: false,
          matchStats: updatedStats,
        ),
      );
    });

    _initHandler();
    add(const HandlerSyncRequested());
  }

  void _initHandler() {
    _stateSub = _handler.sessionStateStream.listen((newState) {
      if (!isClosed) {
        add(EngineStateUpdated(newState));
      }
    });

    _eventSub = _handler.eventStream.listen((event) {
      if (!isClosed) {
        if (event == engine.SessionEventType.typingStatusChanged) {
          final actorId = _handler.activeEventActorId;
          if (actorId != null) {
            add(
              TypingStatusChanged(
                actorId,
                _handler.typingStatus[actorId] ?? false,
              ),
            );
          }
        } else {
          add(
            EngineEventReceived(
              event,
              _handler.activeEventActorId,
              cardCount: _handler.lastCountClaimed,
            ),
          );
        }
      }
    });

    _chatSub = _handler.chatStream.listen((msg) {
      if (!isClosed) {
        add(ChatStreamUpdated(msg));
      }
    });

    _errorSub = _handler.errorStream.listen((failure) {
      if (!isClosed) {
        add(SessionErrorOccurred(failure));
      }
    });
  }

  // Action Logic
  void _onStartRequested(
    SessionStartRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    // Reset state before starting to ensure clean UI
    emit(SessionBlocState.initial());

    _handler.startGame(
      playerCount: event.playerCount,
      thinkingTimeS: event.thinkingTimeS,
    );
  }

  void _onResetRequested(
    SessionResetRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    emit(SessionBlocState.initial());
    add(const HandlerSyncRequested());
  }

  void _onUnitToggled(UnitToggled event, Emitter<SessionBlocState> emit) {
    final ids = List<String>.from(state.selectedUnitIds);
    if (ids.contains(event.unitId)) {
      ids.remove(event.unitId);
    } else {
      if (ids.length >= 4) return;
      ids.add(event.unitId);
    }
    emit(
      state.copyWith(
        selectedUnitIds: ids,
        lastEvent: engine.SessionEventType.cardStaged,
        lastEventActorId: 'me',
        lastEventCardCount: 1,
        lastEventTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _onRankStaged(RankStaged event, Emitter<SessionBlocState> emit) {
    emit(state.copyWith(stagedRank: event.rank, isSelectingRank: false));
  }

  void _onRankSelectionToggle(
    RankSelectionToggleRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    emit(state.copyWith(isSelectingRank: !state.isSelectingRank));
  }

  void _onCardsPlayRequested(
    CardsPlayRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    final isRoundSet = _handler.lastMove != null;
    final rankToPlay = isRoundSet
        ? _handler.lastMove!.declaredRank
        : state.stagedRank;

    if (rankToPlay == null || state.selectedUnitIds.isEmpty) return;

    // OPTIMISTIC UPDATE: Remove cards from local hand immediately
    final playedIds = List<String>.from(state.selectedUnitIds);
    final currentHand = List<engine.Unit>.from(state.engineState.myHand);
    final updatedHand = currentHand
        .where((u) => !playedIds.contains(u.id))
        .toList();

    emit(
      state.copyWith(
        engineState: state.engineState.copyWith(myHand: updatedHand),
        selectedUnitIds: const [],
        clearStagedRank: true,
        isSelectingRank: false,
      ),
    );

    AppLogger.sessionEvent(
      '🎯 Optimistic UI: Removed ${playedIds.length} cards locally',
    );

    // Trigger server action
    _handler.playCards(playedIds, rankToPlay);
  }

  void _onTurnPassRequested(
    TurnPassRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.passTurn();
  }

  void _onChallengeRaiseRequested(
    ChallengeRaiseRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.raiseChallenge();
  }

  void _onHandSortRequested(
    HandSortRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.sortHand();
  }

  void _onHandReorderRequested(
    HandReorderRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.reorderHand(event.oldIndex, event.newIndex);
  }

  void _onHandlerSwapped(
    SessionHandlerSwapped event,
    Emitter<SessionBlocState> emit,
  ) {
    // 1. Clean up old handler
    _stateSub?.cancel();
    _eventSub?.cancel();
    _chatSub?.cancel();

    // Only dispose if it's NOT the singleton WebSocket handler
    if (_handler is! WebSocketSessionHandler) {
      _handler.dispose();
    }

    // 2. Set new handler
    _handler = event.newHandler;

    // 3. Initialize new handler
    _initHandler();

    // 4. Reset state and sync
    emit(SessionBlocState.initial());
    add(const HandlerSyncRequested());
  }

  void _onHandlerSync(
    HandlerSyncRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    emit(
      state.copyWith(
        engineState: _handler.currentState,
        pNames: _handler.pNames,
        isRevealingBluff: _handler.isRevealingBluff,
        lastMove: _handler.lastMove,
        clearLastMove: _handler.lastMove == null,
        gameLog: _handler.gameLog,
        // SYNC LAST EVENT: Crucial for replaying 'shuffling' if missed
        lastEvent: _handler.lastEventType,
        lastEventTimestamp: _handler.lastEventTimestamp,
        lastEventActorId: _handler.activeEventActorId,
        lastEventCardCount: _handler.lastCountClaimed,
      ),
    );
  }

  // Getters for UI convenience
  engine.GameSessionHandler get handler => _handler;

  @override
  Future<void> close() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    _chatSub?.cancel();
    _errorSub?.cancel();
    _eventSub?.cancel();
    _chatSub?.cancel();
    _errorSub?.cancel();
    // Only dispose if it's NOT the singleton WebSocket handler
    if (_handler is! WebSocketSessionHandler) {
      _handler.dispose();
    }
    return super.close();
  }

  void _onErrorOccurred(
    SessionErrorOccurred event,
    Emitter<SessionBlocState> emit,
  ) {
    emit(state.copyWith(failure: event.error));
    // Rollback for optimistic updates: force re-sync with handler
    add(const HandlerSyncRequested());
  }

  void _onErrorCleared(
    SessionErrorCleared event,
    Emitter<SessionBlocState> emit,
  ) {
    emit(state.copyWith(clearFailure: true));
  }

  // Chat Handlers
  void _onChatStreamUpdated(
    ChatStreamUpdated event,
    Emitter<SessionBlocState> emit,
  ) {
    if (event.message['type'] == 'emoji') {
      add(
        EngineEventReceived(
          engine.SessionEventType.emojiReceived,
          event.message['senderId'] == di.sl.authRepository.currentUser?.uid
              ? 'me'
              : event.message['senderId'],
          cardCount: 0, // Not used for emojis
        ),
      );
    }

    final updatedMessages = List<Map<String, dynamic>>.from(state.chatMessages)
      ..add(event.message);

    // Limit chat history locally
    if (updatedMessages.length > 50) {
      updatedMessages.removeAt(0);
    }

    emit(state.copyWith(chatMessages: updatedMessages));
  }

  void _onSendChatMessage(
    SendChatMessage event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.sendChatMessage(event.message);
  }

  void _onSendEmojiMessage(
    SendEmojiMessage event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.sendEmojiMessage(event.emojiId);
  }

  void _onSendTypingStatus(
    SendTypingStatus event,
    Emitter<SessionBlocState> emit,
  ) {
    _handler.setTypingStatus(event.isTyping);
  }

  void _onTypingStatusChanged(
    TypingStatusChanged event,
    Emitter<SessionBlocState> emit,
  ) {
    final updatedTypingStatus = Map<String, bool>.from(state.typingStatus);
    updatedTypingStatus[event.senderId] = event.isTyping;
    emit(state.copyWith(typingStatus: updatedTypingStatus));
  }
}
