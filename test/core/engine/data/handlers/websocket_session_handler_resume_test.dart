import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/data/repositories/auth_repository.dart';
import 'package:veil_core/core/services/audio/audio_service_interface.dart';
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

    // Mock User
    when(() => mockUser.uid).thenReturn('my-uuid');
    when(() => mockAuthRepository.currentUser).thenReturn(mockUser);

    // Mock AudioService (called during onAuthSuccess/handleGameState)
    when(() => mockAudioService.playBgm(any())).thenAnswer((_) async {});
    when(() => mockAudioService.stopBgm()).thenAnswer((_) async {});
    when(() => mockAudioService.playSfx(any())).thenAnswer((_) async {});

    // Inject mocks into ServiceLocator
    // Note: We assume this test file runs in isolation so sl fields are uninitialized
    try {
      sl.authRepository = mockAuthRepository;
    } catch (_) {
      // If already initialized (e.g. by another test in same isolate), we can't overwrite easily
      // But typically flutter test runs separately.
      // If this fails, we might need a different dependency injection strategy for testing.
    }

    try {
      sl.audioService = mockAudioService;
    } catch (_) {}
  });

  group('WebSocketSessionHandler Resume Logic', () {
    test('handleGameState maps activePlayerId (SessionID) to "me"', () async {
      final handler = WebSocketSessionHandler();

      // We need to simulate the message handling
      // WebSocketSessionHandler mixes in WebSocketMessageHandlerMixin
      // We can call handleMessage directly with a JSON string

      final gameStateJson = '''
      {
        "type": "GAME_STATE",
        "data": {
          "phase": "challenging",
          "participants": [
            {
              "id": "my-uuid",
              "sessionId": "short-id",
              "name": "Me",
              "avatarUrl": "url",
              "rank": "GOLD",
              "cardCount": 2,
              "isActive": true,
              "isDisconnected": false
            },
            {
              "id": "other-uuid",
              "sessionId": "other-short",
              "name": "Other",
              "avatarUrl": "url",
              "rank": "SILVER",
              "cardCount": 2,
              "isActive": true,
              "isDisconnected": false
            }
          ],
          "myHand": [],
          "pileCount": 0,
          "activePlayerId": "short-id", 
          "startTime": 1234567890,
          "turnStartTime": 1234567890
        }
      }
      ''';

      // Access private handleMessage via dynamic dispatch or if it's public.
      // logic: handleMessage(dynamic data) is public in mixin?
      // No, handleMessage is public in `WebSocketMessageHandlerMixin`?
      // Checking file: `mixin WebSocketMessageHandlerMixin on WebSocketHandlerBase { ... void handleMessage(dynamic data) { ... } }`
      // It is public.

      handler.handleMessage(gameStateJson);

      // Give stream a moment to update? handleMessage is synchronous for processing but stream add is async-ish
      // However, currentState field is updated synchronously in handleGameState

      expect(handler.currentState.activeParticipantId, equals('me'));
      expect(
        handler.currentState.participants.firstWhere((p) => p.isMe).sessionId,
        equals('short-id'),
      );
    });
  });
}
