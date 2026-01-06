import '../../domain/models/session_enums.dart';
import '../../domain/logic/bot_brain.dart';
import 'base_authoritative_handler.dart';

class LocalBotSessionHandler extends BaseAuthoritativeHandler {
  final BotBrain _brain;
  final Map<String, BotPersonality> _botPersonalities = {};
  int _botThinkingTimeS = 2;

  LocalBotSessionHandler({BotBrain? brain})
    : _brain = brain ?? DefaultBotBrain();

  @override
  final Map<String, String> pNames = {'me': 'You'};

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
      final id = 'p$i';
      _botPersonalities[id] = personalities[(i - 1) % personalities.length];
      pNames[id] = _getBotName(i);
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

    final decision = _brain.decideAction(
      botId: botId,
      currentState: currentState,
      botHand: botHand,
      lastMove: lastMove,
      personality: personality,
    );

    switch (decision.type) {
      case BotAction.play:
        executeMove(botId, decision.units!, decision.declaredRank!);
        break;
      case BotAction.pass:
        passTurn();
        break;
      case BotAction.challenge:
        raiseChallenge();
        break;
    }
  }

  String _getBotName(int index) {
    const names = [
      'Rahul',
      'Priya',
      'Amit',
      'Soniya',
      'Vikram',
      'Anjali',
      'Karan',
      'Neha',
      'Rohan',
    ];
    return names[(index - 1) % names.length];
  }
}
