import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:veil_core/core/engine/domain/logic/bot_brain.dart';
import 'package:veil_core/core/engine/domain/models/participant.dart';
import 'package:veil_core/core/engine/domain/models/session_enums.dart';
import 'package:veil_core/core/engine/domain/models/session_state.dart';
import 'package:veil_core/core/engine/domain/models/unit.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Configuration
const String defaultWsUrl = 'ws://localhost:8080/ws';
const int defaultBotCount = 4; // Fill a standard lobby (1 human + 4 bots)

void main(List<String> args) async {
  final botCount = args.isNotEmpty
      ? int.tryParse(args[0]) ?? defaultBotCount
      : defaultBotCount;
  final wsUrl = args.length > 1 ? args[1] : defaultWsUrl;

  print('🤖 Spawning $botCount Headless Bots connecting to $wsUrl...');

  // Keep the script running and handle cleanup
  final bots = <HeadlessBot>[];
  for (int i = 0; i < botCount; i++) {
    await Future.delayed(Duration(milliseconds: 200 * i));
    final botId = 'mock_bot_${i + 1}';
    final botName = 'Bot ${i + 1}';
    final bot = HeadlessBot(botId, botName, wsUrl);
    bot.start();
    bots.add(bot);
  }

  print('\n[Ctrl+C] to stop bots and clean up accounts.');
  await ProcessSignal.sigint.watch().first;

  print('\n🛑 Shutting down bots & cleaning up accounts...');
  await Future.wait(bots.map((b) => b.cleanup()));
  print('✅ All bots cleaned up. Exiting.');
  exit(0);
}

class HeadlessBot {
  final String id;
  final String name;
  final String wsUrl;
  final BotBrain brain = DefaultBotBrain();
  final BotPersonality personality;

  WebSocketChannel? _channel;
  SessionState? _currentState;
  bool _isConnected = false;
  Completer<void>? _cleanupCompleter;

  HeadlessBot(this.id, this.name, this.wsUrl)
    : personality =
          BotPersonality.values[Random().nextInt(BotPersonality.values.length)];

  void start() {
    _connect();
  }

  Future<void> cleanup() async {
    if (!_isConnected || _channel == null) return;
    print('[$name] 🗑️ Deleting account...');

    // Create a completer to wait for socket flush/close
    _cleanupCompleter = Completer<void>();

    _sendMessage({'type': 'DELETE_ACCOUNT'});

    // Give server a moment to process before cutting connection
    // Since DELETE_ACCOUNT doesn't always send a specific ACK, we wait briefly
    await Future.delayed(Duration(milliseconds: 500));

    await _channel?.sink.close();
    _cleanupCompleter?.complete();
  }

  void _connect() {
    if (_cleanupCompleter != null) return; // Don't reconnect if cleaning up

    print('[$name] Connecting...');
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (message) => _onMessage(message),
        onDone: () {
          if (_cleanupCompleter == null) {
            print('[$name] Disconnected. Reconnecting in 3s...');
            _isConnected = false;
            Future.delayed(Duration(seconds: 3), _connect);
          }
        },
        onError: (error) {
          print('[$name] Error: $error');
          _isConnected = false;
        },
      );
    } catch (e) {
      print('[$name] Connection failed: $e');
      Future.delayed(Duration(seconds: 5), _connect);
    }
  }

  void _sendMessage(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _onMessage(dynamic message) {
    try {
      final Map<String, dynamic> msg = jsonDecode(message as String);
      final type = msg['type'];

      switch (type) {
        case 'WELCOME': // Or Auth Challenge if any
          _sendAuth();
          break;
        case 'AUTH_OK':
          print('[$name] ✅ Authenticated as $name ($id)');
          _isConnected = true;
          // Note: AUTH_OK doesn't have coins, wait for STATS_UPDATE or Room Join
          _joinMatchmaking();
          break;
        case 'STATS_UPDATE': // "STATS_UPDATE" from broadcaster
          _checkCoins(msg['data']);
          break;
        case 'LEADERBOARD_DATA': // Can also get coins here
          break;
        case 'GAME_STATE':
          _handleGameState(msg['data']);
          break;
        case 'PONG':
          break;
        case 'ERROR':
          print('[$name] ❌ Error: ${msg['data']['message']}');
          // If Low Balance error (ErrCodeLowBalance = "LOW_BALANCE" usually)
          if (msg['data']['code'] == 'LOW_BALANCE') {
            print('[$name] ⚠️ Low Balance detected from Error!');
            _attemptRefill();
          }
          break;
      }
    } catch (e) {
      print('[$name] Failed to parse message: $e');
    }
  }

  void _checkCoins(Map<String, dynamic> data) {
    if (data.containsKey('coins')) {
      final coins = data['coins'] as int;
      // print('[$name] Current Coins: $coins');
      if (coins < 100) {
        print('[$name] 💰 Coins low ($coins). Refilling...');
        _attemptRefill();
      }
    }
  }

  void _attemptRefill() {
    _sendMessage({'type': 'REFILL_COINS'});
  }

  void _sendAuth() {
    _sendMessage({
      'type': 'AUTH',
      'token': id,
      'name': name,
      'avatarUrl': 'https://api.dicebear.com/7.x/bottts/png?seed=$id',
    });
  }

  void _joinMatchmaking() {
    _sendMessage({'type': 'START_GAME'});
  }

  void _handleGameState(Map<String, dynamic> data) {
    _currentState = _parseSessionState(data);

    if (_currentState == null) return;

    final phase = _currentState!.currentPhase;
    final activeId = _currentState!.activeParticipantId;

    if (activeId == 'me') {
      final delay = 1000 + Random().nextInt(2000);
      Future.delayed(Duration(milliseconds: delay), () {
        _takeTurn();
      });
    } else {
      if (phase == SessionPhase.challenging &&
          _currentState!.lastActionText?.contains('played') == true) {
        final delay = 500 + Random().nextInt(1500);
        Future.delayed(Duration(milliseconds: delay), () {
          _considerChallenge();
        });
      }
    }
  }

  void _takeTurn() {
    if (_currentState == null || _currentState!.activeParticipantId != 'me') {
      return;
    }

    final decision = brain.decideAction(
      botId: 'me',
      currentState: _currentState!,
      botHand: _currentState!.myHand,
      lastMove: null,
      personality: personality,
    );

    _executeDecision(decision);
  }

  void _considerChallenge() {
    // Challenge logic (placeholder)
  }

  void _executeDecision(BotDecision decision) {
    switch (decision.type) {
      case BotAction.play:
        print(
          '[$name] 🃏 Playing ${decision.units!.length} cards (Rank: ${decision.declaredRank?.name})',
        );
        _sendMessage({
          'type': 'PLAY_CARDS',
          'data': {
            'cardIds': decision.units!.map((u) => u.id).toList(),
            'declaredRank': decision.declaredRank!.name,
          },
        });
        break;
      case BotAction.pass:
        print('[$name] 👋 Passing');
        _sendMessage({'type': 'PASS'});
        break;
      case BotAction.challenge:
        print('[$name] 🚨 CHALLENGING!');
        _sendMessage({'type': 'CHALLENGE'});
        break;
    }
  }

  SessionState _parseSessionState(Map<String, dynamic> data) {
    final handList = (data['myHand'] as List?) ?? [];
    final myHand = handList
        .map(
          (c) => Unit(
            id: c['id'],
            type: UnitType.values.firstWhere(
              (e) => e.name == c['type'],
              orElse: () => UnitType.spades,
            ),
            rank: UnitRank.values.firstWhere(
              (e) => e.name == c['rank'],
              orElse: () => UnitRank.two,
            ),
          ),
        )
        .toList();

    final phaseStr = data['phase'] as String? ?? 'lobby';
    final phase = SessionPhase.values.firstWhere(
      (e) => e.name == phaseStr,
      orElse: () => SessionPhase.lobby,
    );

    String? activeId = data['activePlayerId'];
    if (activeId == id) activeId = 'me';

    final pileCount = data['pileCount'] as int? ?? 0;
    final participants = <Participant>[];

    return SessionState(
      roomId: 'headless',
      participants: participants,
      myHand: myHand,
      pileCount: pileCount,
      currentPhase: phase,
      activeParticipantId: activeId,
    );
  }
}
