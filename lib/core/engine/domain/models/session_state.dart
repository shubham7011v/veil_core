import 'package:equatable/equatable.dart';
import 'participant.dart';
import 'unit.dart';
import 'session_error.dart';

enum SessionPhase {
  lobby,
  thinking, // Waiting for someone to play
  challenging, // Time to challenge
  finished,
}

class SessionState extends Equatable {
  final String roomId;
  final List<Participant> participants;
  final List<Unit> myHand;
  final int pileCount;
  final SessionPhase currentPhase;
  final String? activeParticipantId;
  final String? lastActionText; // e.g. "Rahul played 2 Units"
  final String? winnerId;
  final UnitRank? currentRank;

  final int? turnTimerS;

  final bool isSpectator;
  final SessionError? error;

  const SessionState({
    required this.roomId,
    required this.participants,
    required this.myHand,
    required this.pileCount,
    required this.currentPhase,
    this.activeParticipantId,
    this.lastActionText,
    this.winnerId,
    this.turnTimerS,
    this.currentRank,
    this.isSpectator = false,
    this.error,
  });

  @override
  List<Object?> get props => [
    roomId,
    participants,
    myHand,
    pileCount,
    currentPhase,
    activeParticipantId,
    lastActionText,
    winnerId,
    turnTimerS,
    currentRank,
    isSpectator,
    error,
  ];

  // Factory for initial/empty state
  factory SessionState.initial() {
    return const SessionState(
      roomId: '000',
      participants: [],
      myHand: [],
      pileCount: 0,
      currentPhase: SessionPhase.lobby,
    );
  }

  SessionState copyWith({
    String? roomId,
    List<Participant>? participants,
    List<Unit>? myHand,
    int? pileCount,
    SessionPhase? currentPhase,
    String? activeParticipantId,
    String? lastActionText,
    String? winnerId,
    int? turnTimerS,
    UnitRank? currentRank,
    bool? isSpectator,
    SessionError? error,
    bool clearTimer = false,
    bool clearError = false,
  }) {
    return SessionState(
      roomId: roomId ?? this.roomId,
      participants: participants ?? this.participants,
      myHand: myHand ?? this.myHand,
      pileCount: pileCount ?? this.pileCount,
      currentPhase: currentPhase ?? this.currentPhase,
      activeParticipantId: activeParticipantId ?? this.activeParticipantId,
      lastActionText: lastActionText ?? this.lastActionText,
      winnerId: winnerId ?? this.winnerId,
      turnTimerS: clearTimer ? null : (turnTimerS ?? this.turnTimerS),
      currentRank: currentRank ?? this.currentRank,
      isSpectator: isSpectator ?? this.isSpectator,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
