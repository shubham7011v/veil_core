import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// -- Events --
abstract class VoiceEvent extends Equatable {
  const VoiceEvent();
  @override
  List<Object?> get props => [];
}

class VoiceStateUpdated extends VoiceEvent {
  final Map<String, dynamic> data;
  const VoiceStateUpdated(this.data);
  @override
  List<Object?> get props => [data];
}

class VoiceHandRaised extends VoiceEvent {}

class VoiceMicToggled extends VoiceEvent {} // For Phase 2

// -- State --
class VoiceState extends Equatable {
  final String? currentSpeakerId;
  final List<String> queue;
  final int timeRemainingS;
  final bool isMyTurn;
  final int myQueuePosition; // -1 if not in queue
  final bool isMuted; // Local mute fallback

  const VoiceState({
    this.currentSpeakerId,
    this.queue = const [],
    this.timeRemainingS = 0,
    this.isMyTurn = false,
    this.myQueuePosition = -1,
    this.isMuted = true,
  });

  VoiceState copyWith({
    String? currentSpeakerId,
    List<String>? queue,
    int? timeRemainingS,
    bool? isMyTurn,
    int? myQueuePosition,
    bool? isMuted,
  }) {
    return VoiceState(
      currentSpeakerId: currentSpeakerId ?? this.currentSpeakerId,
      queue: queue ?? this.queue,
      timeRemainingS: timeRemainingS ?? this.timeRemainingS,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      myQueuePosition: myQueuePosition ?? this.myQueuePosition,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  List<Object?> get props => [
    currentSpeakerId,
    queue,
    timeRemainingS,
    isMyTurn,
    myQueuePosition,
    isMuted,
  ];
}

// -- Bloc --
class VoiceBloc extends Bloc<VoiceEvent, VoiceState> {
  final String myUserId;

  VoiceBloc({required this.myUserId}) : super(const VoiceState()) {
    on<VoiceStateUpdated>(_onStateUpdated);
  }

  void _onStateUpdated(VoiceStateUpdated event, Emitter<VoiceState> emit) {
    final data = event.data;
    final speakerId = data['currentSpeakerId'] as String?;
    final qList = (data['queue'] as List<dynamic>? ?? []).cast<String>();
    final time = data['timeRemainingS'] as int? ?? 0;

    final isMeSpeaking = speakerId == myUserId;
    int myPos = -1;
    for (int i = 0; i < qList.length; i++) {
      if (qList[i] == myUserId) {
        myPos = i;
        break;
      }
    }

    emit(
      state.copyWith(
        currentSpeakerId: speakerId,
        queue: qList,
        timeRemainingS: time,
        isMyTurn: isMeSpeaking,
        myQueuePosition: myPos,
        isMuted: !isMeSpeaking, // Simplified: Auto-mute if not speaker
      ),
    );
  }
}
