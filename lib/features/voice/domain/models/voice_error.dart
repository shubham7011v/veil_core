enum VoiceError {
  connectionFailed,
  permissionDenied,
  microphoneUnavailable,
  speakerUnavailable,
  webrtcError,
  invalidState,
  timeout,
}

extension VoiceErrorExtension on VoiceError {
  String get message {
    switch (this) {
      case VoiceError.connectionFailed:
        return 'Voice connection failed';
      case VoiceError.permissionDenied:
        return 'Microphone permission denied';
      case VoiceError.microphoneUnavailable:
        return 'Microphone unavailable';
      case VoiceError.speakerUnavailable:
        return 'Speaker unavailable';
      case VoiceError.webrtcError:
        return 'WebRTC error occurred';
      case VoiceError.invalidState:
        return 'Invalid voice state';
      case VoiceError.timeout:
        return 'Voice connection timeout';
    }
  }

  bool get isRecoverable {
    switch (this) {
      case VoiceError.connectionFailed:
      case VoiceError.timeout:
        return true;
      default:
        return false;
    }
  }
}
