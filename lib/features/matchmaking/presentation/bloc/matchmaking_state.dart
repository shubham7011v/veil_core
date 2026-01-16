import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart';

class MatchmakingState extends Equatable {
  final List<Participant> participants;
  final ConnectionStatus connectionStatus;
  final int secondsRemaining;
  final bool isMatchFound;
  final bool isConnecting;
  final String? error;

  const MatchmakingState({
    this.participants = const [],
    this.connectionStatus = ConnectionStatus.disconnected,
    this.secondsRemaining = 60,
    this.isMatchFound = false,
    this.isConnecting = false,
    this.error,
  });

  MatchmakingState copyWith({
    List<Participant>? participants,
    ConnectionStatus? connectionStatus,
    int? secondsRemaining,
    bool? isMatchFound,
    bool? isConnecting,
    String? error,
  }) {
    return MatchmakingState(
      participants: participants ?? this.participants,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isMatchFound: isMatchFound ?? this.isMatchFound,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    participants,
    connectionStatus,
    secondsRemaining,
    isMatchFound,
    isConnecting,
    error,
  ];
}
