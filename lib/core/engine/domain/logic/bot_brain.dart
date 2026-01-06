import 'dart:math';
import '../models/session_state.dart';
import '../models/session_enums.dart';
import '../models/unit.dart';
import '../models/game_move.dart';

abstract class BotBrain {
  BotDecision decideAction({
    required String botId,
    required SessionState currentState,
    required List<Unit> botHand,
    required GameMove? lastMove,
    required BotPersonality personality,
  });
}

class BotDecision {
  final BotAction type;
  final List<Unit>? units;
  final UnitRank? declaredRank;

  BotDecision.play(this.units, this.declaredRank) : type = BotAction.play;
  BotDecision.pass() : type = BotAction.pass, units = null, declaredRank = null;
  BotDecision.challenge()
    : type = BotAction.challenge,
      units = null,
      declaredRank = null;
}

enum BotAction { play, pass, challenge }

class DefaultBotBrain implements BotBrain {
  final Random _random = Random();

  @override
  BotDecision decideAction({
    required String botId,
    required SessionState currentState,
    required List<Unit> botHand,
    required GameMove? lastMove,
    required BotPersonality personality,
  }) {
    if (botHand.isEmpty) return BotDecision.pass();

    // 1. Challenge Logic
    if (lastMove != null && lastMove.playerId != botId) {
      double challengeChance = 0.15;
      if (personality == BotPersonality.aggressive) challengeChance = 0.35;
      if (personality == BotPersonality.conservative) {
        challengeChance = currentState.pileCount > 8 ? 0.25 : 0.05;
      }
      if (_random.nextDouble() < challengeChance) {
        return BotDecision.challenge();
      }
    }

    // 2. Rank Selection (if starting a new round)
    UnitRank? targetRank = currentState.currentRank;
    bool isStartingRound = targetRank == null;
    if (isStartingRound) {
      targetRank = botHand[_random.nextInt(botHand.length)].rank;
    } else {
      // 3. Play/Pass Logic
      double passChance = 0.15;
      if (personality == BotPersonality.ghost) passChance = 0.45;
      if (personality == BotPersonality.conservative) passChance = 0.25;

      if (_random.nextDouble() < passChance) {
        return BotDecision.pass();
      }
    }

    // 4. Unit Selection
    final matchingCards = botHand.where((u) => u.rank == targetRank).toList();
    List<Unit> botUnitsToPlay = [];

    if (personality == BotPersonality.aggressive) {
      if (matchingCards.isNotEmpty && _random.nextDouble() > 0.2) {
        botUnitsToPlay = matchingCards.sublist(0, min(matchingCards.length, 4));
      } else {
        botUnitsToPlay = ([
          ...botHand,
        ]..shuffle(_random)).sublist(0, min(botHand.length, 3));
      }
    } else if (personality == BotPersonality.conservative) {
      if (matchingCards.isNotEmpty) {
        botUnitsToPlay = [matchingCards.first];
      } else if (_random.nextDouble() < 0.1) {
        botUnitsToPlay = [botHand[_random.nextInt(botHand.length)]];
      } else {
        return BotDecision.pass();
      }
    } else {
      // Balanced or Ghost (Ghost has high pass chance, but if it plays, it plays like balanced)
      if (matchingCards.isNotEmpty && _random.nextDouble() > 0.4) {
        botUnitsToPlay = matchingCards.sublist(
          0,
          min(matchingCards.length, _random.nextInt(2) + 1),
        );
      } else {
        botUnitsToPlay = ([...botHand]..shuffle(_random)).sublist(
          0,
          min(botHand.length, _random.nextInt(2) + 1),
        );
      }
    }

    if (botUnitsToPlay.isEmpty) {
      return BotDecision.pass();
    } else {
      return BotDecision.play(botUnitsToPlay, targetRank);
    }
  }
}
