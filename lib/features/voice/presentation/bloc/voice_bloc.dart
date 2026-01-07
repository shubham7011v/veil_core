import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/error/failure.dart';
import '../../data/voice_audio_manager.dart';
import '../../../../core/utils/app_logger.dart';

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

class VoiceErrorOccurred extends VoiceEvent {
  final Failure failure;
  const VoiceErrorOccurred(this.failure);
  @override
  List<Object?> get props => [failure];
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
  final Failure? failure;

  const VoiceState({
    this.currentSpeakerId,
    this.queue = const [],
    this.timeRemainingS = 0,
    this.isMyTurn = false,
    this.myQueuePosition = -1,
    this.isMuted = true,
    this.failure,
  });

  VoiceState copyWith({
    String? currentSpeakerId,
    List<String>? queue,
    int? timeRemainingS,
    bool? isMyTurn,
    int? myQueuePosition,
    bool? isMuted,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return VoiceState(
      currentSpeakerId: currentSpeakerId ?? this.currentSpeakerId,
      queue: queue ?? this.queue,
      timeRemainingS: timeRemainingS ?? this.timeRemainingS,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      myQueuePosition: myQueuePosition ?? this.myQueuePosition,
      isMuted: isMuted ?? this.isMuted,
      failure: clearFailure ? null : (failure ?? this.failure),
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
    failure,
  ];
}

// -- Bloc --
class VoiceBloc extends Bloc<VoiceEvent, VoiceState> {
  final String myUserId;
  final VoiceSessionHandler handler;
  int _stateVersion = 0; // Track state version for synchronization

  VoiceBloc({required this.myUserId, required this.handler})
    : super(const VoiceState()) {
    // Usage: Register callback used by Handler to push updates to Bloc
    handler.setVoiceCallback((data) => add(VoiceStateUpdated(data)));

    // Initialize Manager
    final audioManager = VoiceAudioManager();
    audioManager.initialize(
      handler,
      onError: (msg, err) => add(VoiceErrorOccurred(UnknownFailure(msg, err))),
    );
    handler.setVoiceManager(audioManager);

    on<VoiceStateUpdated>(_onStateUpdated);
    on<VoiceErrorOccurred>((event, emit) {
      emit(state.copyWith(failure: event.failure));
    });
  }

  @override
  Future<void> close() {
    handler.setVoiceCallback(null);
    handler.setVoiceManager(null);
    VoiceAudioManager().dispose();
    return super.close();
  }

  void _onStateUpdated(VoiceStateUpdated event, Emitter<VoiceState> emit) {
    final data = event.data;
    final speakerId = data['currentSpeakerId'] as String?;
    final qList = (data['queue'] as List<dynamic>? ?? []).cast<String>();
    final timeLeft = data['timeRemainingS'] as int? ?? 0;
    final version = data['version'] as int? ?? 0;

    // Version tracking: only accept newer or equal versions
    if (version < _stateVersion) {
      // Ignore outdated state updates
      return;
    }
    _stateVersion = version;

    // Validate speaker exists in current session (if handler has participant info)
    // Note: We skip validation for now as we don't have synchronous access to session state
    // This could be improved by maintaining a local cache of participants
    if (speakerId != null &&
        speakerId.isNotEmpty &&
        speakerId != 'me' &&
        speakerId != myUserId) {
      // Log voice state update for monitoring
      AppLogger.voiceEvent(
        'Voice state updated',
        data: {
          'speakerId': speakerId,
          'queueLength': qList.length,
          'version': version,
        },
      );
    }

    final myPos = qList.indexOf(myUserId);
    final isMeSpeaking = speakerId == myUserId;

    emit(
      state.copyWith(
        currentSpeakerId: speakerId,
        queue: qList,
        timeRemainingS: timeLeft,
        isMyTurn: isMeSpeaking,
        myQueuePosition: myPos,
        isMuted: !isMeSpeaking,
      ),
    );
  }
}
