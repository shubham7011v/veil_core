import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/engine/engine.dart';
import 'session_event.dart';
import 'session_state.dart';
import '../../../../core/di/service_locator.dart' as di;

class SessionBloc extends Bloc<SessionEvent, SessionBlocState> {
  final GameSessionHandler _handler;
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;

  SessionBloc({GameSessionHandler? handler})
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

    // Engine update handlers
    on<EngineStateUpdated>((event, emit) {
      final isNewRound = _handler.lastMove == null;
      final hasCards = event.state.myHand.isNotEmpty;
      final hadNoCards = state.engineState.myHand.isEmpty;
      final isNowMyTurn = event.state.activeParticipantId == 'me';
      final wasInRound = state.lastMove != null;

      // Detect round reset transition OR initial game start
      final roundJustReset = wasInRound && isNewRound;
      final gameJustStarted = hadNoCards && hasCards && isNewRound;

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
          lastMove: _handler.lastMove,
          clearLastMove: _handler.lastMove == null,
          pNames: _handler.pNames,
          gameLog: _handler.gameLog,
          // Clear stagedRank on round reset or game start, show selector
          clearStagedRank: roundJustReset || gameJustStarted,
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

      emit(
        state.copyWith(
          lastEvent: event.type,
          lastEventActorId: event.actorId,
          lastEventCardCount: event.cardCount,
          lastEventTimestamp: DateTime.now().millisecondsSinceEpoch,
          isRevealingBluff: _handler.isRevealingBluff,
          gameLog: _handler.gameLog,
          lastMove: shouldSync
              ? _handler.lastMove
              : null, // keep existing if null
          // IMPORTANT: Never clearLastMove here. Let EngineStateUpdated do it.
          clearLastMove: false,
        ),
      );
    });

    _initHandler();
    add(const HandlerSyncRequested());
  }

  void _initHandler() {
    _stateSub = _handler.sessionStateStream.listen((newState) {
      add(EngineStateUpdated(newState));
    });

    _eventSub = _handler.eventStream.listen((event) {
      add(
        EngineEventReceived(
          event,
          _handler.activeEventActorId,
          cardCount: _handler.lastCountClaimed,
        ),
      );
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
        lastEvent: SessionEventType.cardStaged,
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

    _handler.playCards(state.selectedUnitIds, rankToPlay);
    emit(
      state.copyWith(
        selectedUnitIds: const [],
        clearStagedRank: true,
        isSelectingRank: false,
      ),
    );
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

  void _onHandlerSync(
    HandlerSyncRequested event,
    Emitter<SessionBlocState> emit,
  ) {
    emit(
      state.copyWith(
        pNames: _handler.pNames,
        isRevealingBluff: _handler.isRevealingBluff,
        lastMove: _handler.lastMove,
        clearLastMove: _handler.lastMove == null,
        gameLog: _handler.gameLog,
      ),
    );
  }

  // Getters for UI convenience
  GameSessionHandler get handler => _handler;

  @override
  Future<void> close() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    _handler.dispose();
    return super.close();
  }
}
