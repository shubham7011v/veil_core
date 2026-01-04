import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/handlers/game_session_handler.dart';
import '../../domain/models/session_state.dart';
import '../../domain/models/session_enums.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/participant.dart';
import '../../domain/models/game_move.dart';

class WebSocketSessionHandler implements GameSessionHandler {
  WebSocketChannel? _channel;

  final _stateController = StreamController<SessionState>.broadcast();
  final _eventController = StreamController<SessionEventType>.broadcast();

  SessionState _currentState = SessionState.initial();

  // Cache for interface properties
  String? _activeEventActorId;
  UnitRank? _lastRankClaimed;
  final int _lastCountClaimed = 0;
  final List<String> _gameLog = [];
  String? _lastBluffWinnerId;
  String? _lastBluffLoserId;
  bool? _isBluffSuccessful;
  GameMove? _lastMove;
  final bool _isRevealingBluff = false;
  final Map<String, String> _pNames = {};

  @override
  Stream<SessionState> get sessionStateStream => _stateController.stream;

  @override
  Stream<SessionEventType> get eventStream => _eventController.stream;

  @override
  String? get activeEventActorId => _activeEventActorId;

  @override
  UnitRank? get lastRankClaimed => _lastRankClaimed;

  @override
  int get lastCountClaimed => _lastCountClaimed;

  @override
  List<String> get gameLog => _gameLog;

  @override
  String? get lastBluffWinnerId => _lastBluffWinnerId;

  @override
  String? get lastBluffLoserId => _lastBluffLoserId;

  @override
  bool? get isBluffSuccessful => _isBluffSuccessful;

  @override
  GameMove? get lastMove => _lastMove;

  @override
  bool get isRevealingBluff => _isRevealingBluff;

  @override
  Map<String, String> get pNames => _pNames;

  /// Connect to WebSocket server
  Future<void> connect(String serverUrl, String firebaseToken) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      // Send auth message
      _send({
        'type': 'AUTH',
        'data': {'token': firebaseToken},
      });

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket Error: $error');
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      rethrow;
    }
  }

  void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void _handleMessage(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final type = msg['type'] as String;

    switch (type) {
      case 'AUTH_OK':
        debugPrint('Auth successful: ${msg['data']}');
        // Send JOIN_ROOM after auth
        _send({'type': 'JOIN_ROOM'});
        break;

      case 'AUTH_FAIL':
        debugPrint('Auth failed: ${msg['data']}');
        break;

      case 'GAME_STATE':
        _handleGameState(msg['data'] as Map<String, dynamic>);
        break;

      case 'ERROR':
        final errorData = msg['data'] as Map<String, dynamic>;
        debugPrint('Server Error: ${errorData['message']}');
        break;
    }
  }

  void _handleGameState(Map<String, dynamic> stateData) {
    // Parse phase
    final phaseStr = stateData['phase'] as String;
    final phase = SessionPhase.values.firstWhere(
      (p) => p.name == phaseStr,
      orElse: () => SessionPhase.lobby,
    );

    // Parse participants
    final participantsList = stateData['participants'] as List<dynamic>? ?? [];
    final participants = participantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      return Participant(
        id: pMap['id'] as String,
        name: pMap['name'] as String,
        unitCount: pMap['cardCount'] as int,
        isMe: false, // Will be set based on player ID match
        isActive: pMap['isActive'] as bool? ?? false,
      );
    }).toList();

    // Parse my hand
    final myHandList = stateData['myHand'] as List<dynamic>? ?? [];
    final myHand = myHandList.map((c) {
      final card = c as Map<String, dynamic>;
      return Unit(
        id: card['id'] as String,
        type: UnitType.values.firstWhere(
          (t) => t.name == card['type'],
          orElse: () => UnitType.spades,
        ),
        rank: UnitRank.values.firstWhere(
          (r) => r.name == card['rank'],
          orElse: () => UnitRank.two,
        ),
      );
    }).toList();

    final newState = SessionState(
      roomId: 'online',
      participants: participants,
      myHand: myHand,
      pileCount: stateData['pileCount'] as int? ?? 0,
      currentPhase: phase,
      activeParticipantId: stateData['activePlayerId'] as String?,
    );

    _currentState = newState;
    _stateController.add(newState);

    // Emit events based on phase transitions
    if (phase == SessionPhase.thinking) {
      _eventController.add(SessionEventType.turnChanged);
    } else if (phase == SessionPhase.challenging) {
      _eventController.add(SessionEventType.cardsPlayed);
    }
  }

  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    _send({'type': 'START_GAME'});
  }

  @override
  void playCards(List<String> unitIds, UnitRank declaredRank) {
    _send({
      'type': 'PLAY_CARDS',
      'data': {'cardIds': unitIds, 'declaredRank': declaredRank.name},
    });
  }

  @override
  void passTurn() {
    _send({'type': 'PASS'});
  }

  @override
  void raiseChallenge() {
    _send({'type': 'CHALLENGE'});
  }

  @override
  void sortHand() {
    // Local operation - sort the hand in state
    final sortedHand = List<Unit>.from(_currentState.myHand)
      ..sort((a, b) {
        if (a.type != b.type) {
          return a.type.index.compareTo(b.type.index);
        }
        return a.rank.index.compareTo(b.rank.index);
      });

    final newState = _currentState.copyWith(myHand: sortedHand);
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  void reorderHand(int oldIndex, int newIndex) {
    // Local operation - reorder hand
    final hand = List<Unit>.from(_currentState.myHand);
    final unit = hand.removeAt(oldIndex);
    hand.insert(newIndex, unit);

    final newState = _currentState.copyWith(myHand: hand);
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _stateController.close();
    _eventController.close();
  }
}
