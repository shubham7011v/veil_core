import 'dart:async';
import '../../../../core/error/failure.dart';
import '../../domain/models/session_enums.dart';
import '../../domain/logic/bot_brain.dart';
import 'base_authoritative_handler.dart';

class LocalBotSessionHandler extends BaseAuthoritativeHandler {
  final BotBrain _brain;
  final Map<String, BotPersonality> _botPersonalities = {};
  int _botThinkingTimeS = 2;
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();

  LocalBotSessionHandler({BotBrain? brain})
    : _brain = brain ?? DefaultBotBrain();

  @override
  final Map<String, String> pNames = {'me': 'You'};

  @override
  Stream<Map<String, dynamic>> get chatStream => _chatController.stream;

  @override
  Stream<Failure> get errorStream => const Stream.empty();

  @override
  void sendChatMessage(String message) {
    // Local chat echo for testing
    _chatController.add({
      'senderId': 'me',
      'senderName': 'You',
      'message': message,
      'time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'isMe': true,
      'type': 'chat',
    });
  }

  @override
  void sendEmojiMessage(String emojiId) {
    // Local emoji echo
    _chatController.add({
      'senderId': 'me',
      'emojiId': emojiId,
      'type': 'emoji',
    });
  }

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    _botThinkingTimeS = thinkingTimeS;
    _botPersonalities.clear();

    final personalities = [
      BotPersonality.conservative, // p1
      BotPersonality.aggressive, // p2
      BotPersonality.balanced, // p3
      BotPersonality.ghost, // p4
      BotPersonality.balanced, // p5
      BotPersonality.conservative, // p6
      BotPersonality.aggressive, // p7
      BotPersonality.balanced, // p8
      BotPersonality.ghost, // p9
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
      'Meera',
      'Arun',
      'Tara',
    ];
    return names[(index - 1) % names.length];
  }
}
