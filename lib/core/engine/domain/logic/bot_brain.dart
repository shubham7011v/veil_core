import 'dart:math';
import '../../../utils/app_logger.dart';
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
    AppLogger.botEvent(
      botId,
      'THINKING',
      data: {
        'personality': personality.name,
        'handSize': botHand.length,
        'pileCount': currentState.pileCount,
        'currentRank': currentState.currentRank?.name,
        'lastMoveBy': lastMove?.playerId,
      },
    );

    if (botHand.isEmpty) {
      AppLogger.botEvent(botId, 'DECISION: PASS (empty hand)');
      return BotDecision.pass();
    }

    // 1. Challenge Logic
    if (lastMove != null && lastMove.playerId != botId) {
      double challengeChance = 0.15;
      if (personality == BotPersonality.aggressive) challengeChance = 0.35;
      if (personality == BotPersonality.conservative) {
        challengeChance = currentState.pileCount > 8 ? 0.25 : 0.05;
      }

      final roll = _random.nextDouble();
      AppLogger.botEvent(
        botId,
        'Challenge check',
        data: {
          'chance': challengeChance,
          'roll': roll.toStringAsFixed(2),
          'willChallenge': roll < challengeChance,
        },
      );

      if (roll < challengeChance) {
        AppLogger.botEvent(botId, 'DECISION: CHALLENGE');
        return BotDecision.challenge();
      }
    }

    // 2. Rank Selection (if starting a new round)
    UnitRank? targetRank = currentState.currentRank;
    bool isStartingRound = targetRank == null;
    if (isStartingRound) {
      targetRank = botHand[_random.nextInt(botHand.length)].rank;
      AppLogger.botEvent(
        botId,
        'Starting round, chose rank: ${targetRank.name}',
      );
    } else {
      // 3. Play/Pass Logic
      double passChance = 0.15;
      if (personality == BotPersonality.ghost) passChance = 0.45;
      if (personality == BotPersonality.conservative) passChance = 0.25;

      final roll = _random.nextDouble();
      AppLogger.botEvent(
        botId,
        'Pass check',
        data: {
          'chance': passChance,
          'roll': roll.toStringAsFixed(2),
          'willPass': roll < passChance,
        },
      );

      if (roll < passChance) {
        AppLogger.botEvent(botId, 'DECISION: PASS');
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
        AppLogger.botEvent(botId, 'DECISION: PASS (conservative, no match)');
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
      AppLogger.botEvent(botId, 'DECISION: PASS (no cards selected)');
      return BotDecision.pass();
    } else {
      final isBluff = botUnitsToPlay.any((u) => u.rank != targetRank);
      AppLogger.botEvent(
        botId,
        'DECISION: PLAY',
        data: {
          'count': botUnitsToPlay.length,
          'declaredRank': targetRank.name,
          'isBluff': isBluff,
          'matchingCount': matchingCards.length,
        },
      );
      return BotDecision.play(botUnitsToPlay, targetRank);
    }
  }
}
