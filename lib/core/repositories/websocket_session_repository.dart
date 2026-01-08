import '../repositories/session_repository.dart';
import '../engine/domain/models/session_state.dart';
import '../engine/domain/models/session_enums.dart';
import '../engine/domain/models/unit.dart';
import '../engine/data/handlers/websocket_session_handler.dart';

/// WebSocket implementation of SessionRepository
class WebSocketSessionRepository implements SessionRepository {
  final WebSocketSessionHandler _handler;

  WebSocketSessionRepository(this._handler);

  @override
  Stream<SessionState> get sessionStateStream => _handler.sessionStateStream;

  @override
  Stream<SessionEventType> get eventStream => _handler.eventStream;

  @override
  Future<void> connect(String serverUrl, String authToken) async {
    await _handler.connect(serverUrl, authToken);
  }

  @override
  Future<void> disconnect() async {
    await _handler.dispose();
  }

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    await _handler.startGame(
      playerCount: playerCount,
      thinkingTimeS: thinkingTimeS,
    );
  }

  @override
  Future<void> playCards(List<String> cardIds, UnitRank declaredRank) async {
    _handler.playCards(cardIds, declaredRank);
  }

  @override
  Future<void> pass() async {
    _handler.passTurn();
  }

  @override
  Future<void> challenge() async {
    _handler.raiseChallenge();
  }

  @override
  Future<void> leaveRoom() async {
    _handler.leaveRoom('');
  }

  @override
  Future<void> deleteAccount() async {
    _handler.deleteAccount();
  }

  @override
  Future<void> dispose() async {
    await _handler.dispose();
  }
}
