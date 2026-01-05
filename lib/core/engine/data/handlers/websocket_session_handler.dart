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
import '../../../../features/auth/domain/models/user_stats.dart';
import '../../../../features/social/domain/models/friend_record.dart';

class WebSocketSessionHandler implements GameSessionHandler {
  WebSocketChannel? _channel;

  final _stateController = StreamController<SessionState>.broadcast();
  final _eventController = StreamController<SessionEventType>.broadcast();
  final _statsController = StreamController<UserStats>.broadcast();
  final _leaderboardController = StreamController<List<UserStats>>.broadcast();
  final _friendsController = StreamController<List<FriendRecord>>.broadcast();

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
  Stream<UserStats> get statsStream => _statsController.stream;

  Stream<List<UserStats>> get leaderboardStream =>
      _leaderboardController.stream;

  Stream<List<FriendRecord>> get friendsStream => _friendsController.stream;

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

        // Parse stats from AUTH_OK response
        final authData = msg['data'] as Map<String, dynamic>;
        if (authData.containsKey('stats')) {
          try {
            final stats = UserStats.fromJson(
              authData['stats'] as Map<String, dynamic>,
            );
            _statsController.add(stats);
            debugPrint(
              'User stats loaded: ${stats.wins} wins, ${stats.rank} rank',
            );
          } catch (e) {
            debugPrint('Failed to parse stats: $e');
          }
        }

        // Send JOIN_ROOM after auth
        _send({'type': 'JOIN_ROOM'});
        break;

      case 'STATS_UPDATE':
        // Handle real-time stats updates (e.g., after game end)
        try {
          final stats = UserStats.fromJson(msg['data'] as Map<String, dynamic>);
          _statsController.add(stats);
          debugPrint('Stats updated: ${stats.wins} wins, ${stats.rank} rank');
        } catch (e) {
          debugPrint('Failed to parse stats update: $e');
        }
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

      case 'LEADERBOARD_DATA':
        try {
          final data = msg['data'] as List<dynamic>;
          final leaderboard = data
              .map((u) => UserStats.fromJson(u as Map<String, dynamic>))
              .toList();
          _leaderboardController.add(leaderboard);
        } catch (e) {
          debugPrint('Failed to parse leaderboard: $e');
        }
        break;

      case 'FRIEND_LIST':
        try {
          final data = msg['data'] as List<dynamic>;
          final friends = data
              .map((f) => FriendRecord.fromJson(f as Map<String, dynamic>))
              .toList();
          _friendsController.add(friends);
        } catch (e) {
          debugPrint('Failed to parse friend list: $e');
        }
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

  // -- Social & Competitive Methods --

  void requestLeaderboard() {
    _send({'type': 'LEADERBOARD_GET'});
  }

  void requestFriends() {
    _send({'type': 'FRIEND_LIST'});
  }

  void addFriend(String friendId) {
    _send({'type': 'FRIEND_REQUEST', 'data': friendId});
  }

  void acceptFriend(String friendId) {
    _send({'type': 'FRIEND_ACCEPT', 'data': friendId});
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _stateController.close();
    _eventController.close();
    _statsController.close();
    _leaderboardController.close();
    _friendsController.close();
  }
}
