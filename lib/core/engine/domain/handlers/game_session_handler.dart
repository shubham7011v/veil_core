import 'dart:async';
import '../models/session_state.dart';
import '../models/unit.dart';
import '../models/session_enums.dart';
import '../models/game_move.dart';

abstract class GameSessionHandler {
  Stream<SessionState> get sessionStateStream;
  Stream<SessionEventType> get eventStream;

  // Optional: detailed getters if needed for specialized UI updates
  String? get activeEventActorId;
  UnitRank? get lastRankClaimed;
  int get lastCountClaimed;
  List<String> get gameLog;
  String? get lastBluffWinnerId;
  String? get lastBluffLoserId;
  bool? get isBluffSuccessful;
  GameMove? get lastMove;

  // UI Helper Properties (Generic)
  bool get isRevealingBluff;
  Map<String, String> get pNames;

  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10});

  void playCards(List<String> unitIds, UnitRank declaredRank);
  void passTurn();
  void raiseChallenge();

  /// Manual & Auto Sorting
  void sortHand();
  void reorderHand(int oldIndex, int newIndex);

  /// Voice & WebRTC
  void setVoiceCallback(Function(Map<String, dynamic> data)? callback);
  void setVoiceManager(dynamic manager);
  Future<void> raiseHand();
  void sendVoiceSDP(Map<String, dynamic> data);
  void sendVoiceICE(Map<String, dynamic> data);

  void dispose();
}
