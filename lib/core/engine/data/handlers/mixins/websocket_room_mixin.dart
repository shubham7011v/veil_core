import 'package:flutter/widgets.dart';
import 'websocket_handler_base.dart';

/// Mixin that handles room and matchmaking operations for WebSocket handler.
/// Includes private rooms, public matchmaking, and room lifecycle.
mixin WebSocketRoomMixin on WebSocketHandlerBase {
  // -- Private Room Methods --

  /// Create a new private room with specified settings
  Future<void> createPrivateRoom({
    required String roomName,
    String? password,
    required int maxPlayers,
    required double bootAmount,
    required bool voiceChat,
    required bool spectatorMode,
  }) async {
    sendMessage({
      'type': 'CREATE_PRIVATE_ROOM',
      'data': {
        'roomName': roomName,
        'password': password,
        'maxPlayers': maxPlayers,
        'bootAmount': bootAmount,
        'voiceChat': voiceChat,
        'spectatorMode': spectatorMode,
      },
    });
  }

  /// Join an existing private room by code
  Future<void> joinPrivateRoom(
    String roomCode, {
    String? password,
    bool isSpectator = false,
  }) async {
    sendMessage({
      'type': 'JOIN_PRIVATE_ROOM',
      'data': {
        'roomCode': roomCode,
        'password': password,
        'isSpectator': isSpectator,
      },
    });
  }

  /// Start the game in a private room (host only)
  void startPrivateGame(String roomCode) {
    sendMessage({
      'type': 'START_PRIVATE_GAME',
      'data': {'roomCode': roomCode},
    });
  }

  /// Leave the current room
  void leaveRoom(String roomCode) {
    sendMessage({
      'type': 'LEAVE_ROOM',
      'data': {'roomCode': roomCode},
    });
  }

  // -- Public Matchmaking Methods --

  /// Join the matchmaking queue for public matches
  void joinMatchmaking() {
    // Check if we are already in an active room (session restoration)
    if (currentSessionState.roomId != '0' &&
        currentSessionState.roomId != '000') {
      debugPrint(
        '⚠️ joinMatchmaking skipped: Already in room ${currentSessionState.roomId}',
      );
      return;
    }

    // Prevent duplicate matchmaking joins
    if (isJoiningMatchmaking) {
      debugPrint('⚠️ joinMatchmaking skipped: already joining');
      return;
    }
    isJoiningMatchmaking = true;
    sendMessage({'type': 'JOIN_ROOM'});

    // Reset flag after a short delay to allow retry if needed
    Future.delayed(const Duration(seconds: 2), () {
      isJoiningMatchmaking = false;
    });
  }

  /// Cancel matchmaking queue
  void cancelMatchmaking() {
    sendMessage({'type': 'CANCEL_MATCHMAKING'});
    isJoiningMatchmaking = false;
    debugPrint('📤 CANCEL_MATCHMAKING sent');
  }
}
