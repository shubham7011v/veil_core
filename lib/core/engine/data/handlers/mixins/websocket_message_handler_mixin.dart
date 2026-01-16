import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../../../di/service_locator.dart';
import '../../../../error/failure.dart';
import '../../../../../../features/auth/domain/models/user_stats.dart';
import '../../../../../../features/challenges/domain/models/daily_challenge.dart';
import '../../../../../../features/social/domain/models/friend_record.dart';
import '../../../../constants/sound_assets.dart';
import '../../../../services/audio/audio_service_interface.dart';
import '../../../domain/models/game_move.dart';
import '../../../domain/models/participant.dart';
import '../../../domain/models/room_event.dart';
import '../../../domain/models/session_enums.dart';
import '../../../domain/models/session_state.dart';
import '../../../domain/models/unit.dart';
import 'websocket_handler_base.dart';

mixin WebSocketMessageHandlerMixin on WebSocketHandlerBase {
  void handleMessage(dynamic data) {
    lastMessageTime = DateTime.now(); // Reset watchdog

    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String;

      if (type != 'PONG') {
        debugPrint('📥 [WebSocket] Received: $type');
      }

      if (type == 'PONG') {
        debugPrint('🏓 [WebSocket] PONG'); // Heartbeat response
        return;
      }

      switch (type) {
        case 'AUTH_OK':
          authTimeoutTimer?.cancel();
          debugPrint('✅ Auth successful: ${msg['data']} (ID: $connectionId)');
          connectionStatus = ConnectionStatus.connected;

          if (connectionCompleter != null &&
              !connectionCompleter!.isCompleted) {
            connectionCompleter!.complete();
          }

          onAuthSuccess(msg['data'] as Map<String, dynamic>);
          break;

        case 'STATS_UPDATE':
          _processStatsUpdate(msg['data'] as Map<String, dynamic>);
          break;

        case 'AUTH_FAIL':
          _processAuthFail(msg['data'] as Map<String, dynamic>);
          break;

        case 'GAME_STATE':
          handleGameState(msg['data'] as Map<String, dynamic>);
          break;

        case 'GAME_ACTION':
          handleGameAction(msg['data'] as Map<String, dynamic>);
          break;

        case 'ERROR':
          _processError(msg['data'] as Map<String, dynamic>);
          break;

        case 'LEADERBOARD_DATA':
          _processLeaderboardData(msg['data'] as List<dynamic>);
          break;

        case 'FRIEND_LIST':
          _processFriendList(msg['data'] as List<dynamic>);
          break;

        case 'ROOM_CREATED':
          _processRoomCreated(msg['data'] as Map<String, dynamic>);
          break;

        case 'ROOM_JOINED':
          _processRoomJoined(msg['data'] as Map<String, dynamic>);
          break;

        case 'ROOM_UPDATE':
          _processRoomUpdate(msg['data'] as Map<String, dynamic>);
          break;

        case 'CHALLENGES_DATA':
          _processChallengesData(msg['data'] as List<dynamic>);
          break;

        case 'CHALLENGE_CLAIM_OK':
          _processChallengeClaimOk(msg['data'] as Map<String, dynamic>);
          break;

        case 'CHAT':
          _processChat(msg['data'] as Map<String, dynamic>);
          break;

        case 'EMOJI':
          _processEmoji(msg['data'] as Map<String, dynamic>);
          break;

        case 'TYPING':
          _processTyping(msg['data'] as Map<String, dynamic>);
          break;
      }
    } catch (e, stack) {
      debugPrint('Error handling WebSocket message: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // Implementation methods
  void _processStatsUpdate(Map<String, dynamic> data) {
    try {
      final stats = UserStats.fromJson(data);
      if (!statsController.isClosed) {
        statsController.add(stats);
      }
      debugPrint('Stats updated: ${stats.wins} wins, ${stats.rank} rank');
    } catch (e) {
      debugPrint('Failed to parse stats update: $e');
    }
  }

  void _processAuthFail(Map<String, dynamic> data) {
    debugPrint('Auth failed: $data');
    if (!errorController.isClosed) {
      errorController.add(
        AuthFailure(data['message'] ?? 'Authentication failed', data),
      );
    }
  }

  void _processError(Map<String, dynamic> errorData) {
    debugPrint('Server Error: ${errorData['message']}');
    if (!errorController.isClosed) {
      errorController.add(
        ServerFailure(
          errorData['message'] ?? 'Unknown server error',
          errorData,
        ),
      );
    }
  }

  void _processLeaderboardData(List<dynamic> data) {
    try {
      final leaderboard = data
          .map((u) => UserStats.fromJson(u as Map<String, dynamic>))
          .toList();
      if (!leaderboardController.isClosed) {
        leaderboardController.add(leaderboard);
      }
    } catch (e) {
      debugPrint('Failed to parse leaderboard: $e');
    }
  }

  void _processFriendList(List<dynamic> data) {
    try {
      final friends = data
          .map((f) => FriendRecord.fromJson(f as Map<String, dynamic>))
          .toList();
      if (!friendsController.isClosed) {
        friendsController.add(friends);
      }
    } catch (e) {
      debugPrint('Failed to parse friend list: $e');
    }
  }

  void _processRoomCreated(Map<String, dynamic> data) {
    try {
      final evt = RoomCreated.fromJson(data);
      if (!roomEventController.isClosed) {
        roomEventController.add(evt);
      }
    } catch (e) {
      debugPrint('Failed to parse ROOM_CREATED: $e');
    }
  }

  void _processRoomJoined(Map<String, dynamic> data) {
    try {
      final evt = RoomJoined.fromJson(data);
      if (!roomEventController.isClosed) {
        roomEventController.add(evt);
      }
    } catch (e) {
      debugPrint('Failed to parse ROOM_JOINED: $e');
    }
  }

  void _processRoomUpdate(Map<String, dynamic> data) {
    try {
      final currentUserId = sl.authRepository.currentUser?.uid;
      final evt = RoomUpdated.fromJson(data, currentUserId: currentUserId);
      debugPrint(
        '🏠 [WebSocket] Room Update: ${evt.participants.length} players',
      );
      if (!roomEventController.isClosed) {
        roomEventController.add(evt);
      }
    } catch (e) {
      debugPrint('Failed to parse ROOM_UPDATE: $e');
    }
  }

  void _processChallengesData(List<dynamic> data) {
    try {
      final challenges = data
          .map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
          .toList();
      if (!challengesController.isClosed) {
        challengesController.add(challenges);
      }
    } catch (e) {
      debugPrint('Failed to parse challenges: $e');
    }
  }

  void _processChallengeClaimOk(Map<String, dynamic> data) {
    try {
      if (!challengeClaimResultController.isClosed) {
        challengeClaimResultController.add(data);
      }
      sl.audioService.playSfx(SoundAssets.turnAlert);
    } catch (e) {
      debugPrint('Failed to parse challenge claim reward: $e');
    }
  }

  void _processChat(Map<String, dynamic> data) {
    try {
      data['type'] = 'chat';
      if (!chatController.isClosed) {
        chatController.add(data);
      }
    } catch (e) {
      debugPrint('Failed to parse chat message: $e');
    }
  }

  void _processEmoji(Map<String, dynamic> data) {
    try {
      data['type'] = 'emoji';
      if (!chatController.isClosed) {
        chatController.add(data);
      }
      sl.audioService.playEmojiSound(data['emojiId'] as String);
    } catch (e) {
      debugPrint('Failed to parse emoji message: $e');
    }
  }

  void _processTyping(Map<String, dynamic> data) {
    try {
      final senderId = data['senderId'] as String;
      final isTyping = data['isTyping'] as bool;

      onTypingStatusChanged(senderId, isTyping);
    } catch (e) {
      debugPrint('Failed to parse typing message: $e');
    }
  }

  void handleGameState(Map<String, dynamic> stateData) {
    // Standardize logs
    final phaseStr = stateData['phase'] as String;
    final players = (stateData['participants'] as List?)?.length ?? 0;
    debugPrint(
      '📊 [WebSocket] GAME_STATE: Phase: $phaseStr, Players: $players',
    );

    // Parse phase
    final phase = SessionPhase.values.firstWhere(
      (p) => p.name == phaseStr,
      orElse: () => SessionPhase.lobby,
    );

    // Audio Triggers based on State Changes
    final previousPhase = currentSessionState.currentPhase;
    // Detect Turn Start
    if (previousPhase != SessionPhase.thinking &&
        phase == SessionPhase.thinking) {
      final activeId = stateData['activePlayerId'] as String?;
      final myId = sl.authRepository.currentUser?.uid;
      if (activeId == myId) {
        try {
          sl.audioService.playSfx(SoundAssets.turnAlert);
          sl.audioService.triggerHaptic(HapticType.heavy);
        } catch (e) {
          debugPrint('Audio error (turn alert): $e');
        }
      }
    }
    // Detect Challenge
    if (previousPhase != SessionPhase.challenging &&
        phase == SessionPhase.challenging) {
      try {
        sl.audioService.playSfx(SoundAssets.challenge);
        sl.audioService.triggerHaptic(HapticType.error); // Alert vibration
      } catch (e) {
        debugPrint('Audio error (challenge): $e');
      }
    }

    // BGM Lifecycle
    if (previousPhase == SessionPhase.lobby && phase != SessionPhase.lobby) {
      try {
        sl.audioService.stopBgm();
      } catch (e) {
        debugPrint('Audio error (stop bgm): $e');
      }
    }
    if (previousPhase != SessionPhase.lobby && phase == SessionPhase.lobby) {
      try {
        sl.audioService.playBgm(SoundAssets.lobbyAmbience);
      } catch (e) {
        debugPrint('Audio error (resume bgm): $e');
      }
    }

    // Parse participants
    final myId = sl.authRepository.currentUser?.uid;
    final participantsList = stateData['participants'] as List<dynamic>? ?? [];
    final participants = participantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      final pId = pMap['id'] as String?; // Might be null for others
      final sessionId = pMap['sessionId'] as String;
      final isMe = (pId != null && pId == myId);

      return Participant(
        id: isMe ? 'me' : (pId ?? sessionId),
        sessionId: sessionId,
        name: pMap['name'] as String,
        avatarUrl: pMap['avatarUrl'] as String?,
        rank: pMap['rank'] as String?,
        unitCount: pMap['cardCount'] as int,
        isMe: isMe,
        isActive: pMap['isActive'] as bool? ?? false,
        isDisconnected: pMap['isDisconnected'] as bool? ?? false,
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

    final activeId = stateData['activePlayerId'] as String?;

    // Parse rich event data
    final lastEvent = stateData['lastEvent'] as String?;
    final actorId = stateData['lastEventActorId'] as String?;
    if (lastEvent != null) {
      debugPrint('🎬 [WebSocket] Last Event: $lastEvent by $actorId');
    }
    final cardCount = stateData['lastEventCardCount'] as int? ?? 0;
    isBluffSuccessful = stateData['isBluffSuccessful'] as bool?;

    // Parse gameLog
    final logData = stateData['gameLog'] as List<dynamic>?;
    if (logData != null) {
      gameLog.clear();
      gameLog.addAll(logData.map((e) => e.toString()));
      debugPrint(
        '📜 [WebSocket] Game Log History (${gameLog.length} entries):',
      );
      for (final entry in gameLog) {
        debugPrint('   - $entry');
      }
    }

    // Map actor IDs to 'me'
    activeEventActorId = actorId == myId ? 'me' : actorId;
    lastCountClaimed = cardCount;
    isRevealingBluff = phase == SessionPhase.revealing;

    // Parse lastMove if present
    final lastMoveData = stateData['lastMove'] as Map<String, dynamic>?;
    if (lastMoveData != null) {
      final movePlayerId = lastMoveData['playerId'] as String;
      final declaredRankStr = lastMoveData['declaredRank'] as String;

      lastMove = GameMove(
        playerId: movePlayerId == myId ? 'me' : movePlayerId,
        declaredRank: UnitRank.values.firstWhere(
          (r) => r.name == declaredRankStr,
          orElse: () => UnitRank.two,
        ),
        actualUnits: [], // Server doesn't send actual cards for security
      );
      lastRankClaimed = lastMove?.declaredRank;
    } else {
      lastMove = null;
      lastRankClaimed = null;
    }

    final newState = SessionState(
      roomId: 'online',
      participants: participants,
      myHand: myHand,
      pileCount: stateData['pileCount'] as int? ?? 0,
      currentPhase: phase,
      activeParticipantId: activeId == myId ? 'me' : activeId,
      startTime: stateData['startTime'] != null
          ? (stateData['startTime'] as int)
          : null,
      turnStartTime: stateData['turnStartTime'] != null
          ? (stateData['turnStartTime'] as int)
          : null,
      turnTimerS: null, // Timer logic handled via turnStartTime
      isSpectator: stateData['isSpectator'] as bool? ?? false,
      isSyncing: false, // Reset syncing flag on full state sync
      createdAt: stateData['createdAt'] as int?,
    );

    currentSessionState = newState;
    if (!stateStreamController.isClosed) {
      stateStreamController.add(newState);
      debugPrint(
        '🧑 [WebSocket] Active Player: ${newState.activeParticipantId}',
      );
    }

    // Emit events based on lastEvent from server
    final lastEventId = stateData['lastEventId'] as String?;

    if (lastEvent != null && !eventController.isClosed) {
      if (lastEventId != null && lastEventId == lastProcessedEventId) {
        // Duplicate event, ignore
      } else {
        if (lastEventId != null) {
          lastProcessedEventId = lastEventId;
        }

        switch (lastEvent) {
          case 'cardsPlayed':
            eventController.add(SessionEventType.cardsPlayed);
            break;
          case 'passed':
            eventController.add(SessionEventType.passed);
            break;
          case 'bluffCalled':
            eventController.add(SessionEventType.bluffCalled);
            break;
          case 'pileDiscarded':
            eventController.add(SessionEventType.pileDiscarded);
            break;
          case 'cardsPickedUp':
            eventController.add(SessionEventType.cardsPickedUp);
            break;
          case 'shuffling':
            eventController.add(SessionEventType.shuffling);
            break;
        }
      }
    }

    // fallback for phase changes if lastEvent is missing
    if (lastEvent == null) {
      if (phase == SessionPhase.thinking) {
        if (!eventController.isClosed) {
          eventController.add(SessionEventType.turnChanged);
        }
      }
    }
  }

  void handleGameAction(Map<String, dynamic> actionData) {
    try {
      final action = actionData['action'] as String?;
      final data = actionData['data'] as Map<String, dynamic>? ?? {};

      if (action == null) return;

      debugPrint('⚙️ [WebSocket] Game Action: $action | Data: $data');

      final myId = sl.authRepository.currentUser?.uid;

      switch (action) {
        case 'PLAY_CARDS':
          final playerId = data['playerId'] as String?;
          final count = data['count'] as int? ?? 0;
          final newPileCount = data['newPileCount'] as int? ?? 0;
          final nextPlayerId = data['nextPlayerId'] as String?;
          final turnStartTime = data['turnStartTime'] as int?;
          final playerNewCardCount = data['playerNewCardCount'] as int?;

          List<Participant> updatedParticipants =
              currentSessionState.participants;
          if (playerId != null && playerNewCardCount != null) {
            updatedParticipants = currentSessionState.participants.map((p) {
              final pId = p.isMe ? myId : p.id;
              if (pId == playerId) {
                return Participant(
                  id: p.id,
                  sessionId: p.sessionId,
                  name: p.name,
                  avatarUrl: p.avatarUrl,
                  rank: p.rank,
                  unitCount: playerNewCardCount,
                  isMe: p.isMe,
                  isActive: p.isActive,
                  isDisconnected: p.isDisconnected,
                );
              }
              return p;
            }).toList();
          }

          currentSessionState = currentSessionState.copyWith(
            pileCount: newPileCount,
            activeParticipantId: nextPlayerId == myId ? 'me' : nextPlayerId,
            currentPhase: SessionPhase.challenging,
            turnStartTime: turnStartTime,
            participants: updatedParticipants,
          );

          if (!stateStreamController.isClosed) {
            stateStreamController.add(currentSessionState);
          }

          activeEventActorId = playerId == myId ? 'me' : playerId;
          lastCountClaimed = count;

          if (!eventController.isClosed) {
            eventController.add(SessionEventType.cardsPlayed);
          }
          break;

        case 'PASS':
          final nextPlayerId = data['nextPlayerId'] as String?;
          final turnStartTime = data['turnStartTime'] as int?;

          currentSessionState = currentSessionState.copyWith(
            activeParticipantId: nextPlayerId == myId ? 'me' : nextPlayerId,
            turnStartTime: turnStartTime,
          );

          if (!stateStreamController.isClosed) {
            stateStreamController.add(currentSessionState);
          }

          final playerId = data['playerId'] as String?;
          activeEventActorId = playerId == myId ? 'me' : playerId;

          if (!eventController.isClosed) {
            eventController.add(SessionEventType.passed);
          }
          break;

        default:
          debugPrint('Unknown game action: $action');
      }
    } catch (e) {
      debugPrint('❌ Error patching game action: $e');
    }
  }

  // Abstract methods for bridge to main handler
  void onAuthSuccess(Map<String, dynamic> authData);
  void onTypingStatusChanged(String senderId, bool isTyping);
}
