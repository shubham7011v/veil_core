import '../models/game_move.dart';
import '../models/participant.dart';

/// Pure logic engine for the game's rules.
/// This ensures that Bot, Online, and Offline modes all use the exact same rules.
class GameRules {
  // -- Constants --
  static const int standardTurnLimitS = 20;
  static const int firstTurnLimitS = 30;
  static const int maxCardsPerMove = 4;

  /// Checks if a move is a bluff based on the actual units played.
  static bool isBluff(GameMove move) {
    return move.actualUnits.any((u) => u.rank != move.declaredRank);
  }

  /// Calculates the next participant ID in the circle.
  static String getNextParticipantId(
    String currentId,
    List<Participant> participants,
  ) {
    final pIds = participants.map((p) => p.id).toList();
    final currentIdx = pIds.indexOf(currentId);
    if (currentIdx == -1) return pIds.first;

    final nextIdx = (currentIdx + 1) % pIds.length;
    return pIds[nextIdx];
  }

  /// Checks if a participant can call a bluff on the last move.
  /// Rule: Only the immediate next player in sequence can call bluff.
  static bool canParticipantCallBluff(
    String participantId,
    String? activeParticipantId,
    GameMove? lastMove,
  ) {
    if (lastMove == null) return false;
    // Only the current active player can challenge the last move
    return participantId == activeParticipantId;
  }

  /// Checks if a player has officially won the game.
  /// Rule: Player must have 0 cards AND survive the challenge cycle.
  static bool hasPlayerWon({
    required String playerId,
    required String? potentialWinnerId,
    required int passCount,
    required int participantCount,
    required bool isNextPlayerStartingRound,
  }) {
    // If someone is confirmed winner, they must have 0 cards and it must have cycled back to them (passes)
    // or the next player must have accepted their move by starting a new round/play.
    if (playerId != potentialWinnerId) return false;

    // Condition 1: Full circle of passes back to the finisher
    if (passCount >= participantCount - 1) return true;

    // Condition 2: Next player accepted the claim by playing their own move
    if (isNextPlayerStartingRound) return true;

    return false;
  }

  /// Determines the results after a bluff challenge.
  /// Returns the ID of the player who must pick up the pile.
  static String getBluffLoserId({
    required bool wasBluff,
    required String blufferId,
    required String challengerId,
  }) {
    return wasBluff ? blufferId : challengerId;
  }

  /// Checks if a win progress should be reset.
  /// Rule: If the potential winner is caught bluffing, they are no longer the finisher.
  static bool shouldResetWinProgress(String loserId, String potentialWinnerId) {
    return loserId == potentialWinnerId;
  }
}
