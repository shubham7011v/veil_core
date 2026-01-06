import '../repositories/voice_repository.dart';
import '../engine/engine.dart';

/// WebSocket implementation of VoiceRepository
class WebSocketVoiceRepository implements VoiceRepository {
  final VoiceSessionHandler _handler;
  final Stream<Map<String, dynamic>> _voiceStateStream;

  WebSocketVoiceRepository(this._handler, this._voiceStateStream);

  @override
  Stream<Map<String, dynamic>> get voiceStateStream => _voiceStateStream;

  @override
  Future<void> initialize() async {
    // Voice initialization is handled by VoiceAudioManager
    // This is a placeholder for future enhancements
  }

  @override
  Future<void> raiseHand() async {
    await _handler.raiseHand();
  }

  @override
  Future<void> sendSDP(Map<String, dynamic> sdpData) async {
    _handler.sendVoiceSDP(sdpData);
  }

  @override
  Future<void> sendICE(Map<String, dynamic> iceData) async {
    _handler.sendVoiceICE(iceData);
  }

  @override
  Future<void> toggleMute() async {
    // Mute toggle is handled by VoiceAudioManager
    // This is a placeholder for future enhancements
  }

  @override
  Future<void> dispose() async {
    // Cleanup handled by handler
  }
}
