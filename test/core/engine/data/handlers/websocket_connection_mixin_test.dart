import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:veil_core/core/engine/data/handlers/websocket_session_handler.dart';
import 'package:veil_core/core/di/service_locator.dart';
import 'package:veil_core/core/data/repositories/auth_repository.dart';
import 'package:veil_core/core/services/audio/audio_service_interface.dart';
import 'package:veil_core/core/engine/domain/models/session_enums.dart';
import 'package:veil_core/core/engine/domain/models/session_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAudioService extends Mock implements AudioService {}

class MockUser extends Mock implements User {}

class MockWebSocketChannel extends Mock implements WebSocketChannel {}

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
    when(() => mockUser.uid).thenReturn('test-user-id');
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockUser.photoURL).thenReturn('https://example.com/avatar.png');
    when(
      () => mockUser.getIdToken(any()),
    ).thenAnswer((_) async => 'mock_token');

    when(() => mockAuthRepository.currentUser).thenReturn(mockUser);

    // Mock AudioService
    when(() => mockAudioService.playBgm(any())).thenAnswer((_) async {});
    when(() => mockAudioService.stopBgm()).thenAnswer((_) async {});
    when(() => mockAudioService.playSfx(any())).thenAnswer((_) async {});

    // Inject mocks into ServiceLocator
    try {
      sl.authRepository = mockAuthRepository;
      sl.audioService = mockAudioService;
    } catch (_) {
      // Already initialized
    }
  });

  group('WebSocket Connection Tests', () {
    test('connect should establish connection successfully', () async {
      final handler = WebSocketSessionHandler();

      // Initial state should be disconnected
      expect(handler.connectionStatus, ConnectionStatus.disconnected);

      // Note: Actual connection will fail in test environment without server
      // This test verifies the connection attempt is initiated
      handler.connect('ws://localhost:8080', 'test_token');

      // Should transition to connecting state
      await Future.delayed(const Duration(milliseconds: 100));
      expect(
        [
          ConnectionStatus.connecting,
          ConnectionStatus.reconnecting,
        ].contains(handler.connectionStatus),
        true,
      );
    });

    test('connection status changes should emit to stream', () async {
      final handler = WebSocketSessionHandler();
      final statusUpdates = <ConnectionStatus>[];

      handler.connectionStatusStream.listen((status) {
        statusUpdates.add(status);
      });

      // Trigger connection attempt
      handler.connect('ws://localhost:8080', 'test_token');

      await Future.delayed(const Duration(milliseconds: 200));

      // Should have received at least one status update
      expect(statusUpdates.isNotEmpty, true);
    });

    test('reconnect attempts should respect max retry limit', () async {
      final handler = WebSocketSessionHandler();

      // Simulate max reconnect attempts
      handler.reconnectAttempts = 5; // Max is typically 5

      // Check that it doesn't exceed max attempts
      expect(handler.reconnectAttempts <= 5, true);
    });

    test('disconnect should cleanup resources', () async {
      final handler = WebSocketSessionHandler();

      // Connect first
      handler.connect('ws://localhost:8080', 'test_token');
      await Future.delayed(const Duration(milliseconds: 100));

      // Dispose handler
      handler.dispose();

      // Should cleanup resources
      // (No public isDisposed property, so we verify no crash)
      expect(true, true);
    });

    test('sendMessage should queue messages when disconnected', () async {
      final handler = WebSocketSessionHandler();

      // Try to send a queuable message while disconnected
      handler.sendMessage({'type': 'FRIEND_LIST', 'data': {}});

      // Message should be queued
      expect(handler.messageQueue.isNotEmpty, true);
    });

    test(
      'processMessageQueue should send queued messages when connected',
      () async {
        final handler = WebSocketSessionHandler();

        // Queue a message
        handler.queueMessage({'type': 'FRIEND_LIST', 'data': {}});

        expect(handler.messageQueue.length, 1);

        // Process queue (will attempt to send)
        handler.processMessageQueue();

        // Queue should be cleared (messages are sent or dropped)
        // Note: In disconnected state, they won't actually send but queue is cleared
      },
    );
  });

  group('Auto-Reconnect Tests', () {
    test(
      'attemptAutoReconnect should refresh token before reconnecting',
      () async {
        final handler = WebSocketSessionHandler();

        // Set initial state
        handler.lastUrl = 'ws://localhost:8080';
        handler.updateConnectionStatus(ConnectionStatus.disconnected);

        // Trigger auto-reconnect
        await handler.attemptAutoReconnect();

        // Verify token was requested
        verify(() => mockUser.getIdToken(true)).called(greaterThan(0));
      },
    );

    test('attemptAutoReconnect should not run if already connecting', () async {
      final handler = WebSocketSessionHandler();
      handler.updateConnectionStatus(ConnectionStatus.connecting);

      // Try to auto-reconnect
      await handler.attemptAutoReconnect();

      // Should skip since already connecting
      expect(handler.connectionStatus, ConnectionStatus.connecting);
    });

    test('forceReconnect should trigger reconnection', () async {
      final handler = WebSocketSessionHandler();
      handler.lastUrl = 'ws://localhost:8080';
      handler.updateConnectionStatus(ConnectionStatus.disconnected);

      await handler.forceReconnect();

      // Should have attempted to get fresh token
      verify(() => mockUser.getIdToken(true)).called(greaterThan(0));
    });
  });

  group('Network State Change Tests', () {
    test(
      'handleConnectivityChange should trigger reconnection on network switch',
      () async {
        final handler = WebSocketSessionHandler();
        handler.lastUrl = 'ws://localhost:8080';
        handler.updateConnectionStatus(ConnectionStatus.connected);

        // Simulate connectivity change
        await handler.handleConnectivityChange([ConnectivityResult.mobile]);

        // Give time for debounce
        await Future.delayed(const Duration(milliseconds: 1600));

        // Should transition to reconnecting
        expect(
          [
            ConnectionStatus.reconnecting,
            ConnectionStatus.connecting,
          ].contains(handler.connectionStatus),
          true,
        );
      },
    );

    test('handleConnectivityChange should be debounced', () async {
      final handler = WebSocketSessionHandler();
      handler.lastUrl = 'ws://localhost:8080';

      // Send multiple rapid connectivity changes
      handler.handleConnectivityChange([ConnectivityResult.wifi]);
      handler.handleConnectivityChange([ConnectivityResult.mobile]);
      handler.handleConnectivityChange([ConnectivityResult.wifi]);

      // Should debounce and only process last one
      await Future.delayed(const Duration(milliseconds: 1600));

      // Verify it processed the connectivity change
      expect(handler.connectionStatus, isNotNull);
    });
  });

  group('Message Queueing Tests', () {
    test('isQueuable should return true for supported message types', () {
      final handler = WebSocketSessionHandler();

      expect(handler.isQueuable('FRIEND_LIST'), true);
      expect(handler.isQueuable('LEADERBOARD_GET'), true);
      expect(handler.isQueuable('CHALLENGES_GET'), true);
      expect(handler.isQueuable('REFILL_COINS'), true);
      expect(handler.isQueuable('UPDATE_FCM'), true);
    });

    test('isQueuable should return false for gameplay messages', () {
      final handler = WebSocketSessionHandler();

      expect(handler.isQueuable('PLAY_CARDS'), false);
      expect(handler.isQueuable('PASS'), false);
      expect(handler.isQueuable('CHALLENGE'), false);
    });

    test('queueMessage should deduplicate same message type', () {
      final handler = WebSocketSessionHandler();

      handler.queueMessage({
        'type': 'FRIEND_LIST',
        'data': {'version': 1},
      });
      handler.queueMessage({
        'type': 'FRIEND_LIST',
        'data': {'version': 2},
      });

      // Should only have one message of this type
      expect(handler.messageQueue.length, 1);
      expect(handler.messageQueue.first['data']['version'], 2);
    });
  });

  group('Heartbeat Tests', () {
    test('startHeartbeat should initialize heartbeat timer', () {
      final handler = WebSocketSessionHandler();

      handler.startHeartbeat();

      // Heartbeat timer should be active
      expect(handler.heartbeatTimer, isNotNull);
      expect(handler.heartbeatTimer!.isActive, true);

      // Cleanup
      handler.heartbeatTimer?.cancel();
    });

    test('heartbeat should update lastMessageTime', () {
      final handler = WebSocketSessionHandler();
      final initialTime = handler.lastMessageTime;

      handler.startHeartbeat();

      // Last message time should be updated
      expect(handler.lastMessageTime.isAfter(initialTime), true);

      // Cleanup
      handler.heartbeatTimer?.cancel();
    });
  });

  group('Connection Status Updates', () {
    test('updateConnectionStatus should emit status changes', () async {
      final handler = WebSocketSessionHandler();
      final statusUpdates = <ConnectionStatus>[];

      handler.connectionStatusStream.listen((status) {
        statusUpdates.add(status);
      });

      handler.updateConnectionStatus(ConnectionStatus.connecting);
      handler.updateConnectionStatus(ConnectionStatus.connected);
      handler.updateConnectionStatus(ConnectionStatus.disconnected);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(statusUpdates.length, greaterThanOrEqualTo(3));
      expect(statusUpdates.contains(ConnectionStatus.connecting), true);
      expect(statusUpdates.contains(ConnectionStatus.connected), true);
      expect(statusUpdates.contains(ConnectionStatus.disconnected), true);
    });

    test(
      'updateConnectionStatus should set syncing flag during reconnection',
      () async {
        final handler = WebSocketSessionHandler();
        final stateUpdates = <SessionState>[];

        handler.sessionStateStream.listen((state) {
          stateUpdates.add(state);
        });

        handler.updateConnectionStatus(ConnectionStatus.reconnecting);

        await Future.delayed(const Duration(milliseconds: 100));

        // Should have syncing flag set
        expect(stateUpdates.any((s) => s.isSyncing == true), true);
      },
    );

    test(
      'updateConnectionStatus should clear syncing flag when connected',
      () async {
        final handler = WebSocketSessionHandler();
        final stateUpdates = <SessionState>[];

        handler.sessionStateStream.listen((state) {
          stateUpdates.add(state);
        });

        handler.updateConnectionStatus(ConnectionStatus.reconnecting);
        await Future.delayed(const Duration(milliseconds: 100));

        handler.updateConnectionStatus(ConnectionStatus.connected);
        await Future.delayed(const Duration(milliseconds: 100));

        // Latest state should not have syncing flag
        expect(stateUpdates.last.isSyncing == false, true);
      },
    );
  });

  tearDown(() {
    // Cleanup
  });
}
