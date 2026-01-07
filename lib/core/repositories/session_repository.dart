import '../engine/domain/models/session_state.dart';
import '../engine/domain/models/session_enums.dart';
import '../engine/domain/models/unit.dart';

/// Repository interface for session/game state management
abstract class SessionRepository {
  /// Stream of session state updates
  Stream<SessionState> get sessionStateStream;

  /// Stream of session events (card played, turn changed, etc.)
  Stream<SessionEventType> get eventStream;

  /// Connect to a game session
  Future<void> connect(String serverUrl, String authToken);

  /// Disconnect from current session
  Future<void> disconnect();

  /// Start a new game
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10});

  /// Play cards
  Future<void> playCards(List<String> cardIds, UnitRank declaredRank);

  /// Pass turn
  Future<void> pass();

  /// Challenge the current play
  Future<void> challenge();

  /// Leave the current room
  Future<void> leaveRoom();

  /// Request account deletion from backend
  Future<void> deleteAccount();

  /// Dispose resources
  Future<void> dispose();
}
