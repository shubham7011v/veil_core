import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart';

class MatchmakingState extends Equatable {
  final List<Participant> participants;
  final ConnectionStatus connectionStatus;
  final int secondsRemaining;
  final bool isMatchFound;
  final bool isConnecting;
  final String? error;
  final MatchmakingSideEffect? effect;

  const MatchmakingState({
    this.participants = const [],
    this.connectionStatus = ConnectionStatus.disconnected,
    this.secondsRemaining = 60,
    this.isMatchFound = false,
    this.isConnecting = false,
    this.error,
    this.effect,
  });

  MatchmakingState copyWith({
    List<Participant>? participants,
    ConnectionStatus? connectionStatus,
    int? secondsRemaining,
    bool? isMatchFound,
    bool? isConnecting,
    String? Function()? error,
    MatchmakingSideEffect? Function()? effect,
  }) {
    return MatchmakingState(
      participants: participants ?? this.participants,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isMatchFound: isMatchFound ?? this.isMatchFound,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error != null ? error() : this.error,
      effect: effect != null ? effect() : this.effect,
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
    effect,
  ];
}

// Side Effects
abstract class MatchmakingSideEffect extends Equatable {
  const MatchmakingSideEffect();
  @override
  List<Object?> get props => [];
}

class MatchmakingNavigateToSession extends MatchmakingSideEffect {
  const MatchmakingNavigateToSession();
}

class MatchmakingShowTimeoutDialog extends MatchmakingSideEffect {
  const MatchmakingShowTimeoutDialog();
}

class MatchmakingTriggerHaptic extends MatchmakingSideEffect {
  const MatchmakingTriggerHaptic();
}

class MatchmakingShowSnackBar extends MatchmakingSideEffect {
  final String message;
  final bool isError;
  const MatchmakingShowSnackBar(this.message, {this.isError = false});
  @override
  List<Object?> get props => [message, isError];
}

class MatchmakingPop extends MatchmakingSideEffect {
  const MatchmakingPop();
}
