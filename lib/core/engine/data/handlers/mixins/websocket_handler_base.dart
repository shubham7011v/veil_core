import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../domain/models/session_state.dart';
import '../../../domain/models/session_enums.dart';
import '../../../domain/models/room_event.dart';
import '../../../domain/models/game_move.dart';
import '../../../domain/models/unit.dart';
import '../../../../../features/auth/domain/models/user_stats.dart';
import '../../../../../features/social/domain/models/friend_record.dart';
import '../../../../../features/challenges/domain/models/daily_challenge.dart';
import '../../../../error/failure.dart';

/// Base mixin that defines the interface required by all WebSocket handler mixins.
/// This allows mixins to access the core send functionality and state.
mixin WebSocketHandlerBase {
  /// Core setters/getters
  void sendMessage(Map<String, dynamic> message, {bool force = false});
  SessionState get currentSessionState;
  set currentSessionState(SessionState state);
  StreamController<SessionState> get stateStreamController;

  // --- Connection State ---
  WebSocketChannel? get channel;
  set channel(WebSocketChannel? value);
  ConnectionStatus get connectionStatus;
  set connectionStatus(ConnectionStatus value);
  StreamController<ConnectionStatus> get connectionStatusController;
  StreamSubscription? get subscription;
  set subscription(StreamSubscription? value);
  Completer<void>? get connectionCompleter;
  set connectionCompleter(Completer<void>? value);
  int get connectionId;
  set connectionId(int value);

  // --- Reconnection Logic ---
  int get reconnectAttempts;
  set reconnectAttempts(int value);
  String? get lastUrl;
  set lastUrl(String? value);
  String? get fcmToken;
  set fcmToken(String? value);
  bool get isConnecting;
  set isConnecting(bool value);

  // --- Queues and Sequence ---
  List<Map<String, dynamic>> get messageQueue;
  int get nextSequence;
  set nextSequence(int value);

  // --- Controllers for various events ---
  StreamController<SessionEventType> get eventController;
  StreamController<UserStats> get statsController;
  StreamController<List<UserStats>> get leaderboardController;
  StreamController<List<FriendRecord>> get friendsController;
  StreamController<RoomEvent> get roomEventController;
  StreamController<List<DailyChallenge>> get challengesController;
  StreamController<Map<String, dynamic>> get challengeClaimResultController;
  StreamController<Map<String, dynamic>> get chatController;
  StreamController<Failure> get errorController;

  // --- Matchmaking ---
  bool get isJoiningMatchmaking;
  set isJoiningMatchmaking(bool value);

  // --- Timers & Timekeeping ---
  Timer? get heartbeatTimer;
  set heartbeatTimer(Timer? value);
  DateTime get lastMessageTime;
  set lastMessageTime(DateTime value);
  Timer? get authTimeoutTimer;
  set authTimeoutTimer(Timer? value);
  Timer? get watchdogTimer;
  set watchdogTimer(Timer? value);
  Timer? get reconnectTimer;
  set reconnectTimer(Timer? value);

  // --- Rich Game State ---
  bool? get isBluffSuccessful;
  set isBluffSuccessful(bool? value);
  List<String> get gameLog;
  String? get activeEventActorId;
  set activeEventActorId(String? value);
  int get lastCountClaimed;
  set lastCountClaimed(int value);
  bool get isRevealingBluff;
  set isRevealingBluff(bool value);
  GameMove? get lastMove;
  set lastMove(GameMove? value);
  UnitRank? get lastRankClaimed;
  set lastRankClaimed(UnitRank? value);
  String? get lastProcessedEventId;
  set lastProcessedEventId(String? value);
  String? get lastBluffWinnerId;
  set lastBluffWinnerId(String? value);
  String? get lastBluffLoserId;
  set lastBluffLoserId(String? value);
  Map<String, String> get pNames;
  Map<String, bool> get typingStatus;
}
