import 'package:equatable/equatable.dart';
import 'participant.dart';
import 'unit.dart';
import 'session_error.dart';

enum SessionPhase {
  lobby,
  starting, // 10s countdown
  thinking, // Waiting for someone to play
  challenging, // Time to challenge
  revealing, // Waiting for bluff reveal animation
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
  final int? startTime; // For lobby countdown
  final int? turnStartTime; // For turn timer
  final int? turnTimerS; // Local countdown if any
  final bool isSpectator;
  final bool isSyncing; // Added for Phase 4 UX
  final SessionError? error;
  final int? createdAt;

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
    this.startTime,
    this.turnStartTime,
    this.isSpectator = false,
    this.isSyncing = false,
    this.error,
    this.createdAt,
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
    startTime,
    turnStartTime,
    isSpectator,
    isSyncing,
    error,
    createdAt,
  ];

  // Factory for initial/empty state
  factory SessionState.initial() {
    return const SessionState(
      roomId: '000',
      participants: [],
      myHand: [],
      pileCount: 0,
      currentPhase: SessionPhase.lobby,
      isSyncing: false,
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
    int? startTime,
    int? turnStartTime,
    bool? isSpectator,
    bool? isSyncing,
    SessionError? error,
    int? createdAt,
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
      startTime: startTime ?? this.startTime,
      turnStartTime: turnStartTime ?? this.turnStartTime,
      isSpectator: isSpectator ?? this.isSpectator,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
