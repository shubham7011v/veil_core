/// Repository interface for voice chat management
abstract class VoiceRepository {
  /// Stream of voice state updates
  Stream<Map<String, dynamic>> get voiceStateStream;

  /// Initialize voice connection
  Future<void> initialize();

  /// Raise hand to speak
  Future<void> raiseHand();

  /// Send WebRTC SDP offer/answer
  Future<void> sendSDP(Map<String, dynamic> sdpData);

  /// Send WebRTC ICE candidate
  Future<void> sendICE(Map<String, dynamic> iceData);

  /// Toggle microphone mute
  Future<void> toggleMute();

  /// Dispose resources
  Future<void> dispose();
}
