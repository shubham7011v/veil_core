import 'package:equatable/equatable.dart';
import 'participant.dart';
import 'unit.dart';

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

  final int? turnTimerS;

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
    bool clearTimer = false,
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
    );
  }
}
