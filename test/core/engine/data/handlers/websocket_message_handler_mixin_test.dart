import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/data/repositories/auth_repository.dart';
import 'package:veil_core/core/services/audio/audio_service_interface.dart';
import 'package:veil_core/core/engine/domain/models/session_enums.dart';
import 'package:veil_core/core/engine/domain/models/session_state.dart';
import 'package:veil_core/core/error/failure.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAudioService extends Mock implements AudioService {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuthRepository;
  late MockAudioService mockAudioService;
  late MockUser mockUser;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockAudioService = MockAudioService();
    mockUser = MockUser();

    when(() => mockUser.uid).thenReturn('test-user-id');
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockAuthRepository.currentUser).thenReturn(mockUser);
    when(() => mockAudioService.playBgm(any())).thenAnswer((_) async {});
    when(() => mockAudioService.stopBgm()).thenAnswer((_) async {});
    when(() => mockAudioService.playSfx(any())).thenAnswer((_) async {});
    when(() => mockAudioService.triggerHaptic(any())).thenAnswer((_) async {});

    try {
      sl.authRepository = mockAuthRepository;
      sl.audioService = mockAudioService;
    } catch (_) {}
  });

  group('Message Handling Tests', () {
    test('handleMessage should parse AUTH_OK correctly', () async {
      final handler = WebSocketSessionHandler();
      final authOkMessage = '''
      {
        "type": "AUTH_OK",
        "data": {
          "userId": "test-user-id",
          "sessionId": "session-123"
        }
      }
      ''';

      handler.handleMessage(authOkMessage);

      // Should transition to connected
      expect(handler.connectionStatus, ConnectionStatus.connected);
    });

    test('handleMessage should handle GAME_STATE message', () async {
      final handler = WebSocketSessionHandler();
      final stateUpdates = <SessionState>[];

      handler.sessionStateStream.listen((state) {
        stateUpdates.add(state);
      });

      final gameStateMessage = '''
      {
        "type": "GAME_STATE",
        "data": {
          "phase": "thinking",
          "participants": [
            {
              "id": "test-user-id",
              "sessionId": "session-1",
              "name": "Player 1",
              "avatarUrl": "url",
              "rank": "GOLD",
              "cardCount": 5,
              "isActive": true,
              "isDisconnected": false
            }
          ],
          "myHand": [],
          "pileCount": 0,
          "activePlayerId": "test-user-id",
          "startTime": 1234567890,
          "turnStartTime": 1234567890
        }
      }
      ''';

      handler.handleMessage(gameStateMessage);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(stateUpdates.isNotEmpty, true);
      expect(stateUpdates.last.currentPhase, SessionPhase.thinking);
      expect(stateUpdates.last.activeParticipantId, 'me');
      expect(stateUpdates.last.participants.length, 1);
    });

    test('handleMessage should handle ERROR messages', () async {
      final handler = WebSocketSessionHandler();
      final errors = <Failure>[];

      handler.errorStream.listen((error) {
        errors.add(error);
      });

      final errorMessage = '''
      {
        "type": "ERROR",
        "data": {
          "code": "INVALID_MOVE",
          "message": "Invalid card selection"
        }
      }
      ''';

      handler.handleMessage(errorMessage);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(errors.isNotEmpty, true);
      expect(errors.first, isA<ServerFailure>());
    });

    test('handleMessage should handle GAME_ACTION for PLAY_CARDS', () async {
      final handler = WebSocketSessionHandler();
      final events = <SessionEventType>[];

      handler.eventStream.listen((event) {
        events.add(event);
      });

      // Set up initial state
      handler.handleMessage('''
      {
        "type": "GAME_STATE",
        "data": {
          "phase": "thinking",
          "participants": [
            {
              "id": "test-user-id",
              "sessionId": "session-1",
              "name": "Player 1",
              "cardCount": 5,
              "isActive": true,
              "isDisconnected": false
            }
          ],
          "myHand": [],
          "pileCount": 0,
          "activePlayerId": "test-user-id"
        }
      }
      ''');

      final gameActionMessage = '''
      {
        "type": "GAME_ACTION",
        "data": {
          "action": "PLAY_CARDS",
          "data": {
            "playerId": "test-user-id",
            "count": 2,
            "newPileCount": 2,
            "nextPlayerId": "other-player",
            "turnStartTime": 1234567890,
            "playerNewCardCount": 3
          }
        }
      }
      ''';

      handler.handleMessage(gameActionMessage);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.contains(SessionEventType.cardsPlayed), true);
    });

    test('handleMessage should handle STATS_UPDATE', () async {
      final handler = WebSocketSessionHandler();
      final statsUpdates = [];

      handler.statsStream.listen((stats) {
        statsUpdates.add(stats);
      });

      final statsMessage = '''
      {
        "type": "STATS_UPDATE",
        "data": {
          "userId": "test-user-id",
          "name": "Test User",
          "rank": "GOLD",
          "wins": 10,
          "losses": 5,
          "coins": 1000
        }
      }
      ''';

      handler.handleMessage(statsMessage);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(statsUpdates.isNotEmpty, true);
    });

    test('handleMessage should ignore PONG heartbeat responses', () {
      final handler = WebSocketSessionHandler();
      final pongMessage = '{"type": "PONG"}';

      // Should not throw or cause issues
      handler.handleMessage(pongMessage);

      // Last message time should be updated
      expect(handler.lastMessageTime, isNotNull);
    });
  });

  group('Game State Processing Tests', () {
    test('handleGameState should map activePlayerId to me correctly', () {
      final handler = WebSocketSessionHandler();

      final gameStateData = {
        'phase': 'thinking',
        'participants': [
          {
            'id': 'test-user-id',
            'sessionId': 'session-1',
            'name': 'Me',
            'avatarUrl': 'url',
            'rank': 'GOLD',
            'cardCount': 5,
            'isActive': true,
            'isDisconnected': false,
          },
          {
            'id': 'other-id',
            'sessionId': 'session-2',
            'name': 'Other',
            'avatarUrl': 'url',
            'rank': 'SILVER',
            'cardCount': 5,
            'isActive': false,
            'isDisconnected': false,
          },
        ],
        'myHand': [],
        'pileCount': 0,
        'activePlayerId': 'test-user-id',
      };

      handler.handleGameState(gameStateData);

      expect(handler.currentState.activeParticipantId, 'me');
      expect(handler.currentState.participants.any((p) => p.isMe), true);
    });

    test('handleGameState should parse participant cards correctly', () {
      final handler = WebSocketSessionHandler();

      final gameStateData = {
        'phase': 'thinking',
        'participants': [
          {
            'id': 'test-user-id',
            'sessionId': 'session-1',
            'name': 'Me',
            'cardCount': 3,
            'isActive': true,
            'isDisconnected': false,
          },
        ],
        'myHand': [
          {'id': 'card-1', 'type': 'spades', 'rank': 'ace'},
          {'id': 'card-2', 'type': 'hearts', 'rank': 'two'},
        ],
        'pileCount': 0,
      };

      handler.handleGameState(gameStateData);

      expect(handler.currentState.myHand.length, 2);
      expect(handler.currentState.myHand[0].id, 'card-1');
      expect(handler.currentState.myHand[1].id, 'card-2');
    });

    test('handleGameState should trigger audio on phase changes', () {
      final handler = WebSocketSessionHandler();

      // Set up initial lobby state
      handler.handleGameState({
        'phase': 'lobby',
        'participants': [
          {
            'id': 'test-user-id',
            'sessionId': 'session-1',
            'name': 'Me',
            'cardCount': 0,
            'isActive': false,
            'isDisconnected': false,
          },
        ],
        'myHand': [],
        'pileCount': 0,
      });

      // Transition to thinking (game start)
      handler.handleGameState({
        'phase': 'thinking',
        'participants': [
          {
            'id': 'test-user-id',
            'sessionId': 'session-1',
            'name': 'Me',
            'cardCount': 5,
            'isActive': true,
            'isDisconnected': false,
          },
        ],
        'myHand': [],
        'pileCount': 0,
        'activePlayerId': 'test-user-id',
      });

      // Should have stopped BGM and played turn alert
      verify(() => mockAudioService.stopBgm()).called(greaterThan(0));
      verify(() => mockAudioService.playSfx(any())).called(greaterThan(0));
    });

    test('handleGameState should emit events based on lastEvent', () async {
      final handler = WebSocketSessionHandler();
      final events = <SessionEventType>[];

      handler.eventStream.listen((event) {
        events.add(event);
      });

      handler.handleGameState({
        'phase': 'challenging',
        'participants': [
          {
            'id': 'test-user-id',
            'sessionId': 'session-1',
            'name': 'Me',
            'cardCount': 5,
            'isActive': false,
            'isDisconnected': false,
          },
        ],
        'myHand': [],
        'pileCount': 2,
        'lastEvent': 'cardsPlayed',
        'lastEventId': 'event-1',
      });

      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.contains(SessionEventType.cardsPlayed), true);
    });
  });

  group('Message Type Handling Tests', () {
    test('should handle ROOM_CREATED message', () async {
      final handler = WebSocketSessionHandler();
      final roomEvents = [];

      handler.roomEventStream.listen((event) {
        roomEvents.add(event);
      });

      handler.handleMessage('''
      {
        "type": "ROOM_CREATED",
        "data": {
          "roomCode": "ABC123",
          "roomName": "Test Room"
        }
      }
      ''');

      await Future.delayed(const Duration(milliseconds: 100));

      expect(roomEvents.isNotEmpty, true);
    });

    test('should handle CHAT message', () async {
      final handler = WebSocketSessionHandler();
      final chatMessages = [];

      handler.chatStream.listen((msg) {
        chatMessages.add(msg);
      });

      handler.handleMessage('''
      {
        "type": "CHAT",
        "data": {
          "senderId": "other-player",
          "message": "Hello!"
        }
      }
      ''');

      await Future.delayed(const Duration(milliseconds: 100));

      expect(chatMessages.isNotEmpty, true);
      expect(chatMessages.first['type'], 'chat');
    });

    test('should handle EMOJI message and play emoji sound', () async {
      final handler = WebSocketSessionHandler();

      when(
        () => mockAudioService.playEmojiSound(any()),
      ).thenAnswer((_) async {});

      handler.handleMessage('''
      {
        "type": "EMOJI",
        "data": {
          "senderId": "other-player",
          "emojiId": "thumbs_up"
        }
      }
      ''');

      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockAudioService.playEmojiSound('thumbs_up')).called(1);
    });
  });

  tearDown(() {
    // Cleanup
  });
}
