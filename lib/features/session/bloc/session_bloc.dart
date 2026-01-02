import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/game_session_handler.dart';
import '../logic/local_bot_session_handler.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionBlocState> {
  final GameSessionHandler _handler;
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;

  SessionBloc({GameSessionHandler? handler})
    : _handler = handler ?? LocalBotSessionHandler(),
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

    // Engine update handlers
    on<EngineStateUpdated>(
      (event, emit) => emit(state.copyWith(engineState: event.state)),
    );
    on<EngineEventReceived>(
      (event, emit) => emit(
        state.copyWith(
          lastEvent: event.type,
          lastEventActorId: event.actorId,
          lastEventCardCount: event.cardCount,
        ),
      ),
    );

    _initHandler();
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
    _handler.startGame(
      playerCount: event.playerCount,
      thinkingTimeS: event.thinkingTimeS,
    );
  }

  void _onUnitToggled(UnitToggled event, Emitter<SessionBlocState> emit) {
    final ids = List<String>.from(state.selectedUnitIds);
    if (ids.contains(event.unitId)) {
      ids.remove(event.unitId);
    } else {
      if (ids.length >= 4) return;
      ids.add(event.unitId);
    }
    emit(state.copyWith(selectedUnitIds: ids));
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
    emit(state.copyWith(selectedUnitIds: const [], clearStagedRank: true));
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

  // Getters for UI convenience (mimicking old provider getters)
  GameSessionHandler get handler => _handler;

  @override
  Future<void> close() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    _handler.dispose();
    return super.close();
  }
}
