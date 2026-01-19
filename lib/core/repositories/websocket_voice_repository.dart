import '../repositories/voice_repository.dart';
import '../engine/engine.dart';
import '../utils/app_logger.dart';

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
    AppLogger.voiceEvent('Voice: Raising hand');
    await _handler.raiseHand();
  }

  @override
  Future<void> sendSDP(Map<String, dynamic> sdpData) async {
    AppLogger.voiceEvent('Voice: Sending SDP', data: {'type': sdpData['type']});
    _handler.sendVoiceSDP(sdpData);
  }

  @override
  Future<void> sendICE(Map<String, dynamic> iceData) async {
    AppLogger.voiceEvent('Voice: Sending ICE candidate');
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
