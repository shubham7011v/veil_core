import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../../../../core/error/failure.dart';
import '../../domain/models/match_stats.dart';

sealed class SessionSideEffect {
  const SessionSideEffect();
}

class SessionNavigateToHome extends SessionSideEffect {
  const SessionNavigateToHome();
}

class SessionShowTurnPopup extends SessionSideEffect {
  final String message;
  const SessionShowTurnPopup(this.message);
}

class SessionTriggerHaptic extends SessionSideEffect {
  final bool isLight;
  const SessionTriggerHaptic({this.isLight = false});
}

class SessionShowSnackBar extends SessionSideEffect {
  final String message;
  final bool isError;
  const SessionShowSnackBar(this.message, {this.isError = false});
}

class SessionShowErrorNotification extends SessionSideEffect {
  final String message;
  const SessionShowErrorNotification(this.message);
}

class SessionBlocState extends Equatable {
  final engine.SessionState engineState;

  // -- UI Selection State --
  final List<String> selectedUnitIds;
  final engine.UnitRank? stagedRank;
  final bool isSelectingRank;

  // -- Event State for Animations --
  final engine.SessionEventType lastEvent;
  final String? lastEventActorId;
  final int lastEventCardCount;
  final bool isRevealingBluff;
  final bool? isBluffSuccessful; // New field
  final engine.GameMove? lastMove;
  final int
  lastEventTimestamp; // Used to trigger animations on same-type events

  // -- Player Info --
  final Map<String, String> pNames;

  // -- Game History --
  final List<String> gameLog;
  final List<Map<String, dynamic>> chatMessages;
  final Map<String, bool> typingStatus;

  // -- Match Statistics --
  final MatchStats matchStats;
  final DateTime? gameStartTime;

  // -- Error State --
  final Failure? failure;

  // -- Side Effects --
  final SessionSideEffect? effect;

  const SessionBlocState({
    required this.engineState,
    required this.selectedUnitIds,
    this.stagedRank,
    required this.isSelectingRank,
    required this.lastEvent,
    this.lastEventActorId,
    this.lastEventCardCount = 0,
    required this.isRevealingBluff,
    this.isBluffSuccessful,
    this.lastMove,
    this.lastEventTimestamp = 0,
    required this.pNames,
    required this.gameLog,
    required this.chatMessages,
    required this.typingStatus,
    required this.matchStats,
    this.gameStartTime,
    this.failure,
    this.effect,
  });

  factory SessionBlocState.initial() => SessionBlocState(
    engineState: engine.SessionState.initial(),
    selectedUnitIds: const [],
    isSelectingRank: false,
    lastEvent: engine.SessionEventType.none,
    isRevealingBluff: false,
    isBluffSuccessful: null,
    lastEventTimestamp: 0,
    pNames: const {},
    gameLog: const [],
    chatMessages: const [],
    typingStatus: const {},
    matchStats: const MatchStats(),
    effect: null,
  );

  SessionBlocState copyWith({
    engine.SessionState? engineState,
    List<String>? selectedUnitIds,
    engine.UnitRank? stagedRank,
    bool? isSelectingRank,
    engine.SessionEventType? lastEvent,
    String? lastEventActorId,
    int? lastEventCardCount,
    bool? isRevealingBluff,
    bool? isBluffSuccessful,
    engine.GameMove? lastMove,
    int? lastEventTimestamp,
    Map<String, String>? pNames,
    List<String>? gameLog,
    List<Map<String, dynamic>>? chatMessages,
    Map<String, bool>? typingStatus,
    MatchStats? matchStats,
    DateTime? gameStartTime,
    Failure? failure,
    bool clearStagedRank = false,
    bool clearLastMove = false,
    bool clearFailure = false,
    bool clearGameStartTime = false,
    SessionSideEffect? Function()? effect,
  }) {
    return SessionBlocState(
      engineState: engineState ?? this.engineState,
      selectedUnitIds: selectedUnitIds ?? this.selectedUnitIds,
      stagedRank: clearStagedRank ? null : (stagedRank ?? this.stagedRank),
      isSelectingRank: isSelectingRank ?? this.isSelectingRank,
      lastEvent: lastEvent ?? this.lastEvent,
      lastEventActorId: lastEventActorId ?? this.lastEventActorId,
      lastEventCardCount: lastEventCardCount ?? this.lastEventCardCount,
      isRevealingBluff: isRevealingBluff ?? this.isRevealingBluff,
      isBluffSuccessful: isBluffSuccessful ?? this.isBluffSuccessful,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      lastEventTimestamp: lastEventTimestamp ?? this.lastEventTimestamp,
      pNames: pNames ?? this.pNames,
      gameLog: gameLog ?? this.gameLog,
      chatMessages: chatMessages ?? this.chatMessages,
      typingStatus: typingStatus ?? this.typingStatus,
      matchStats: matchStats ?? this.matchStats,
      gameStartTime: clearGameStartTime
          ? null
          : (gameStartTime ?? this.gameStartTime),
      failure: clearFailure ? null : (failure ?? this.failure),
      effect: effect != null ? effect() : this.effect,
    );
  }

  // -- Derived Getters --
  bool get isMyTurn => engineState.activeParticipantId == 'me';

  // Show rank selector only when explicitly toggled via isSelectingRank
  bool get shouldShowRankSelector => isSelectingRank && !isRoundSet;

  bool get isRoundSet => lastMove != null;

  int get pileCount => engineState.pileCount;

  String get roundStatus {
    if (isRoundSet) return "${lastMove!.declaredRank.name.toUpperCase()}S";
    if (stagedRank != null) return stagedRank!.name.toUpperCase();

    // Dynamic status for empty round
    if (isMyTurn) return "SELECT RANK";

    final activeId = engineState.activeParticipantId;
    final name = pNames[activeId]?.split(' ').first.toUpperCase() ?? "PLAYER";
    return "$name SELECTING";
  }

  String getPlayerName(String id) => pNames[id] ?? id;

  bool get canSubmit {
    if (!isMyTurn) return false;
    if (selectedUnitIds.isEmpty) return false;
    if (!isRoundSet && stagedRank == null) return false;
    return true;
  }

  @override
  List<Object?> get props => [
    engineState,
    selectedUnitIds,
    stagedRank,
    isSelectingRank,
    lastEvent,
    lastEventActorId,
    lastEventCardCount,
    isRevealingBluff,
    isBluffSuccessful,
    lastMove,
    lastEventTimestamp,
    pNames,
    gameLog,
    chatMessages,
    typingStatus,
    matchStats,
    gameStartTime,
    failure,
    effect,
  ];
}
