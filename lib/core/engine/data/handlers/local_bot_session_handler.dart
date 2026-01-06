import 'dart:async';
import 'dart:math';

import '../../domain/models/session_enums.dart';
import '../../domain/models/unit.dart';
import 'base_authoritative_handler.dart';

class LocalBotSessionHandler extends BaseAuthoritativeHandler {
  final Map<String, BotPersonality> _botPersonalities = {};
  int _botThinkingTimeS = 2;

  @override
  final Map<String, String> pNames = {
    'me': 'You',
    'p1': 'Rahul',
    'p2': 'Priya',
    'p3': 'Amit',
    'p4': 'Soniya',
    'p5': 'Vikram',
    'p6': 'Anjali',
    'p7': 'Karan',
    'p8': 'Neha',
    'p9': 'Rohan',
  };

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    _botThinkingTimeS = thinkingTimeS;
    _botPersonalities.clear();

    final personalities = [
      BotPersonality.conservative,
      BotPersonality.aggressive,
      BotPersonality.balanced,
      BotPersonality.ghost,
      BotPersonality.balanced,
      BotPersonality.conservative,
      BotPersonality.aggressive,
      BotPersonality.balanced,
      BotPersonality.ghost,
    ];

    for (int i = 1; i < playerCount; i++) {
      _botPersonalities['p$i'] = personalities[(i - 1) % personalities.length];
    }

    return super.startGame(
      playerCount: playerCount,
      thinkingTimeS: thinkingTimeS,
    );
  }

  @override
  void onTurnActive(String participantId) {
    if (participantId != 'me') {
      _scheduleBotTurn(participantId);
    }
  }

  void _scheduleBotTurn(String botId) async {
    await Future.delayed(Duration(seconds: _botThinkingTimeS));

    // Check if game ended or phase changed while waiting
    if (currentState.activeParticipantId != botId) return;

    final personality = _botPersonalities[botId] ?? BotPersonality.balanced;
    final botHand = getHand(botId);
    if (botHand == null || botHand.isEmpty) return;

    // 1. Challenge Logic
    if (lastMove != null && lastMove!.playerId != botId) {
      double challengeChance = 0.15;
      if (personality == BotPersonality.aggressive) challengeChance = 0.35;
      if (personality == BotPersonality.conservative) {
        challengeChance = currentState.pileCount > 8 ? 0.25 : 0.05;
      }
      if (Random().nextDouble() < challengeChance) {
        raiseChallenge();
        return;
      }
    }

    // 2. Rank Selection (if starting a new round)
    UnitRank? targetRank = currentRank;
    if (targetRank == null) {
      targetRank = botHand[Random().nextInt(botHand.length)].rank;
      setRoundRank(targetRank);
    } else {
      // 3. Play/Pass Logic
      double passChance = 0.15;
      if (personality == BotPersonality.ghost) passChance = 0.45;
      if (personality == BotPersonality.conservative) passChance = 0.25;

      if (Random().nextDouble() < passChance) {
        passTurn();
        return;
      }
    }

    // 4. Unit Selection
    final matchingCards = botHand.where((u) => u.rank == targetRank).toList();
    List<Unit> botUnitsToPlay = [];

    if (personality == BotPersonality.aggressive) {
      if (matchingCards.isNotEmpty && Random().nextDouble() > 0.2) {
        botUnitsToPlay = matchingCards.sublist(0, min(matchingCards.length, 4));
      } else {
        botUnitsToPlay = ([
          ...botHand,
        ]..shuffle()).sublist(0, min(botHand.length, 3));
      }
    } else if (personality == BotPersonality.conservative) {
      if (matchingCards.isNotEmpty) {
        botUnitsToPlay = [matchingCards.first];
      } else if (Random().nextDouble() < 0.1) {
        botUnitsToPlay = [botHand[Random().nextInt(botHand.length)]];
      } else {
        passTurn();
        return;
      }
    } else {
      if (matchingCards.isNotEmpty && Random().nextDouble() > 0.4) {
        botUnitsToPlay = matchingCards.sublist(
          0,
          min(matchingCards.length, Random().nextInt(2) + 1),
        );
      } else {
        botUnitsToPlay = ([
          ...botHand,
        ]..shuffle()).sublist(0, min(botHand.length, Random().nextInt(2) + 1));
      }
    }

    if (botUnitsToPlay.isEmpty) {
      passTurn();
    } else {
      executeMove(botId, botUnitsToPlay, targetRank);
    }
  }

  // Use dynamic to match interface, though ignored here
  @override
  void setVoiceCallback(Function(Map<String, dynamic> data)? callback) {}

  @override
  void setVoiceManager(dynamic manager) {}

  @override
  Future<void> raiseHand() async {}

  @override
  void sendVoiceSDP(Map<String, dynamic> data) {}

  @override
  void sendVoiceICE(Map<String, dynamic> data) {}
}
