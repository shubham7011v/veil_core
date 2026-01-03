import '../models/game_move.dart';
import '../models/participant.dart';

/// Pure logic engine for the game's rules.
/// This ensures that Bot, Online, and Offline modes all use the exact same rules.
class GameRules {
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

  /// Checks if a challenge can be raised given the current game state.
  static bool canRaiseChallenge(GameMove? lastMove) {
    // Challenge can only be raised if there was a previous move
    return lastMove != null;
  }

  /// Validates if a move can be played.
  /// Note: In this game, any move is "legal" as long as the player has the cards.
  static bool isValidMove(
    String playerId,
    String activeParticipantId,
    List<String> unitIds,
  ) {
    if (playerId != activeParticipantId) return false;
    if (unitIds.isEmpty) return false;
    return true;
  }
}
