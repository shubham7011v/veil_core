abstract class VoiceSessionHandler {
  void setVoiceCallback(Function(Map<String, dynamic> data)? callback);
  void setVoiceManager(dynamic manager);
  Future<void> raiseHand();
  void sendVoiceSDP(Map<String, dynamic> data);
  void sendVoiceICE(Map<String, dynamic> data);
}
