import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/handlers/game_session_handler.dart';
import '../../domain/handlers/voice_session_handler.dart';
import '../../domain/models/session_state.dart';
import '../../domain/models/session_enums.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/game_move.dart';
import '../../../../features/auth/domain/models/user_stats.dart';
import '../../../../features/social/domain/models/friend_record.dart';
import '../../domain/models/room_event.dart';
import '../../../../features/challenges/domain/models/daily_challenge.dart';
import '../../../../features/profile/domain/models/match_history_item.dart';
import '../../../../features/voice/data/voice_audio_manager.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/constants/sound_assets.dart';
import '../../../../core/error/failure.dart';
import 'mixins/mixins.dart';

class WebSocketSessionHandler extends GameSessionHandler
    with
        WidgetsBindingObserver,
        WebSocketHandlerBase,
        WebSocketSocialMixin,
        WebSocketGameActionsMixin,
        WebSocketRoomMixin,
        WebSocketConnectionMixin,
        WebSocketMessageHandlerMixin
    implements VoiceSessionHandler {
  WebSocketChannel? _channel;

  final _stateController = StreamController<SessionState>.broadcast();
  final _eventController = StreamController<SessionEventType>.broadcast();
  final _statsController = StreamController<UserStats>.broadcast();
  final _leaderboardController = StreamController<List<UserStats>>.broadcast();
  final _friendsController = StreamController<List<FriendRecord>>.broadcast();
  final _roomEventController = StreamController<RoomEvent>.broadcast();
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _challengesController =
      StreamController<List<DailyChallenge>>.broadcast();
  final _challengeClaimResultController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _matchHistoryController =
      StreamController<List<MatchHistoryItem>>.broadcast();
  final _errorController = StreamController<Failure>.broadcast();

  // Connection state
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _lastUrl;
  String? _fcmToken;

  // Managed connection artifacts
  StreamSubscription? _subscription;
  StreamSubscription? _connectivitySubscription;
  Completer<void>? _connectionCompleter;
  int _connectionId = 0;

  // Message Queue for non-critical requests during reconnection
  final List<Map<String, dynamic>> _messageQueue = [];

  // Connection lock to prevent duplicate simultaneous connections
  bool _isConnecting = false;

  // Prevent duplicate matchmaking joins
  bool _isJoiningMatchmaking = false;

  int _nextSequence = 1;

  // Heartbeat & Watchdog
  Timer? _heartbeatTimer;
  Timer? _watchdogTimer;
  DateTime _lastMessageTime = DateTime.now();

  // Auth timeout
  Timer? _authTimeoutTimer;

  @override
  set fcmToken(String? value) {
    _fcmToken = value;
    // If connected, update server immediately
    if (connectionStatus == ConnectionStatus.connected) {
      sendMessage({
        'type': 'UPDATE_FCM',
        'data': {'token': value},
      });
    }
  }

  void setFcmToken(String token) => fcmToken = token;

  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  // Voice Callbacks & Managers
  Function(Map<String, dynamic> data)? _voiceCallback;

  @override
  void setVoiceCallback(Function(Map<String, dynamic> data)? callback) =>
      _voiceCallback = callback;

  VoiceAudioManager? _voiceManager;

  @override
  void setVoiceManager(dynamic manager) {
    if (manager is VoiceAudioManager) {
      _voiceManager = manager;
    }
  }

  SessionState _currentState = SessionState.initial();

  // Cache for interface properties
  String? _activeEventActorId;
  UnitRank? _lastRankClaimed;
  int _lastCountClaimed = 0;
  final List<String> _gameLog = [];
  String? _lastBluffWinnerId;
  String? _lastBluffLoserId;
  bool? _isBluffSuccessful;
  GameMove? _lastMove;
  bool _isRevealingBluff = false;
  final Map<String, String> _pNames = {};
  String? _lastProcessedEventId;
  UserStats? _lastStats;
  List<FriendRecord> _friends = [];
  final Map<String, bool> _typingStatusMap = {};

  WebSocketSessionHandler() {
    _currentState = SessionState.initial();
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    // Register connectivity observer - active network monitoring
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      handleConnectivityChange,
    );
  }

  // --- WebSocketHandlerBase Interface Implementation ---
  @override
  WebSocketChannel? get channel => _channel;
  @override
  set channel(WebSocketChannel? value) => _channel = value;

  @override
  ConnectionStatus get connectionStatus => _connectionStatus;
  @override
  set connectionStatus(ConnectionStatus value) => _connectionStatus = value;

  @override
  StreamController<ConnectionStatus> get connectionStatusController =>
      _connectionStatusController;

  @override
  StreamSubscription? get subscription => _subscription;
  @override
  set subscription(StreamSubscription? value) => _subscription = value;

  @override
  Completer<void>? get connectionCompleter => _connectionCompleter;
  @override
  set connectionCompleter(Completer<void>? value) =>
      _connectionCompleter = value;

  @override
  int get connectionId => _connectionId;
  @override
  set connectionId(int value) => _connectionId = value;

  @override
  int get reconnectAttempts => _reconnectAttempts;
  @override
  set reconnectAttempts(int value) => _reconnectAttempts = value;

  @override
  String? get lastUrl => _lastUrl;
  @override
  set lastUrl(String? value) => _lastUrl = value;

  @override
  String? get fcmToken => _fcmToken;

  @override
  bool get isConnecting => _isConnecting;
  @override
  set isConnecting(bool value) => _isConnecting = value;

  @override
  List<Map<String, dynamic>> get messageQueue => _messageQueue;

  @override
  int get nextSequence => _nextSequence;
  @override
  set nextSequence(int value) => _nextSequence = value;

  @override
  StreamController<SessionState> get stateStreamController => _stateController;
  @override
  StreamController<SessionEventType> get eventController => _eventController;
  @override
  StreamController<UserStats> get statsController => _statsController;
  @override
  StreamController<List<UserStats>> get leaderboardController =>
      _leaderboardController;
  @override
  StreamController<List<FriendRecord>> get friendsController =>
      _friendsController;
  @override
  StreamController<RoomEvent> get roomEventController => _roomEventController;
  @override
  StreamController<List<DailyChallenge>> get challengesController =>
      _challengesController;
  @override
  StreamController<Map<String, dynamic>> get challengeClaimResultController =>
      _challengeClaimResultController;
  @override
  StreamController<Map<String, dynamic>> get chatController => _chatController;
  @override
  StreamController<List<MatchHistoryItem>> get matchHistoryController =>
      _matchHistoryController;
  @override
  StreamController<Failure> get errorController => _errorController;

  @override
  bool get isJoiningMatchmaking => _isJoiningMatchmaking;
  @override
  set isJoiningMatchmaking(bool value) => _isJoiningMatchmaking = value;

  @override
  Timer? get heartbeatTimer => _heartbeatTimer;
  @override
  set heartbeatTimer(Timer? value) => _heartbeatTimer = value;

  @override
  DateTime get lastMessageTime => _lastMessageTime;
  @override
  set lastMessageTime(DateTime value) => _lastMessageTime = value;

  @override
  Timer? get authTimeoutTimer => _authTimeoutTimer;
  @override
  set authTimeoutTimer(Timer? value) => _authTimeoutTimer = value;

  @override
  Timer? get watchdogTimer => _watchdogTimer;
  @override
  set watchdogTimer(Timer? value) => _watchdogTimer = value;

  @override
  Timer? get reconnectTimer => _reconnectTimer;
  @override
  set reconnectTimer(Timer? value) => _reconnectTimer = value;

  @override
  SessionState get currentSessionState => _currentState;
  @override
  set currentSessionState(SessionState value) => _currentState = value;

  @override
  bool? get isBluffSuccessful => _isBluffSuccessful;
  @override
  set isBluffSuccessful(bool? value) => _isBluffSuccessful = value;

  @override
  List<String> get gameLog => _gameLog;

  @override
  String? get activeEventActorId => _activeEventActorId;
  @override
  set activeEventActorId(String? value) => _activeEventActorId = value;

  @override
  int get lastCountClaimed => _lastCountClaimed;
  @override
  set lastCountClaimed(int value) => _lastCountClaimed = value;

  @override
  bool get isRevealingBluff => _isRevealingBluff;
  @override
  set isRevealingBluff(bool value) => _isRevealingBluff = value;

  @override
  GameMove? get lastMove => _lastMove;
  @override
  set lastMove(GameMove? value) => _lastMove = value;

  @override
  UnitRank? get lastRankClaimed => _lastRankClaimed;
  @override
  set lastRankClaimed(UnitRank? value) => _lastRankClaimed = value;

  @override
  String? get lastProcessedEventId => _lastProcessedEventId;
  @override
  set lastProcessedEventId(String? value) => _lastProcessedEventId = value;

  @override
  String? get lastBluffWinnerId => _lastBluffWinnerId;
  @override
  set lastBluffWinnerId(String? value) => _lastBluffWinnerId = value;

  @override
  String? get lastBluffLoserId => _lastBluffLoserId;
  @override
  set lastBluffLoserId(String? value) => _lastBluffLoserId = value;

  @override
  Map<String, String> get pNames => _pNames;

  @override
  Map<String, bool> get typingStatus => _typingStatusMap;

  // --- GameSessionHandler Stream Getters ---
  @override
  Stream<SessionState> get sessionStateStream => _stateController.stream;
  @override
  Stream<SessionEventType> get eventStream => _eventController.stream;
  @override
  Stream<Failure> get errorStream => _errorController.stream;
  @override
  SessionState get currentState => _currentState;
  @override
  Stream<Map<String, dynamic>> get chatStream => _chatController.stream;

  // Additional public streams for UI
  Stream<UserStats> get statsStream => _statsController.stream;
  Stream<List<UserStats>> get leaderboardStream =>
      _leaderboardController.stream;
  Stream<List<FriendRecord>> get friendsStream => _friendsController.stream;
  Stream<RoomEvent> get roomEventStream => _roomEventController.stream;
  Stream<List<DailyChallenge>> get challengesStream =>
      _challengesController.stream;
  Stream<Map<String, dynamic>> get challengeClaimResultStream =>
      _challengeClaimResultController.stream;

  UserStats? get lastStats => _lastStats;
  List<FriendRecord> get currentFriends => _friends;

  // --- Voice Interface Bridge ---
  void receiveVoiceState(Map<String, dynamic> data) {
    _voiceCallback?.call(data);
  }

  @override
  Future<void> raiseHand() async {
    sendMessage({'type': 'VOICE_RAISE_HAND'});
  }

  @override
  void sendVoiceSDP(Map<String, dynamic> data) {
    sendMessage({'type': 'VOICE_SDP', 'data': data});
  }

  @override
  void sendVoiceICE(Map<String, dynamic> data) {
    sendMessage({'type': 'VOICE_ICE', 'data': data});
  }

  // --- Bridge Methods for Mixins ---
  @override
  void setupMessageListener(String firebaseToken, {String? displayName}) {
    final curId = _connectionId;
    _subscription?.cancel();
    _subscription = _channel?.stream.listen(
      (data) => handleMessage(data),
      onError: (e) {
        if (curId == _connectionId) {
          handleConnectionFailure(firebaseToken, displayName: displayName);
        }
      },
      onDone: () {
        if (curId == _connectionId) {
          handleConnectionFailure(firebaseToken, displayName: displayName);
        }
      },
    );
  }

  @override
  void onAuthSuccess(Map<String, dynamic> authData) {
    reconnectAttempts = 0;
    updateConnectionStatus(ConnectionStatus.connected);
    startHeartbeat();
    processMessageQueue();

    if (_fcmToken != null) {
      sendMessage({
        'type': 'UPDATE_FCM',
        'data': {'token': _fcmToken},
      });
    }

    if (authData.containsKey('stats')) {
      try {
        final stats = UserStats.fromJson(
          authData['stats'] as Map<String, dynamic>,
        );
        _lastStats = stats;
        if (!_statsController.isClosed) {
          _statsController.add(stats);
        }
      } catch (e) {
        AppLogger.error('Error parsing stats', exception: e);
      }
    }

    try {
      sl.audioService.playBgm(SoundAssets.lobbyAmbience);
    } catch (e) {
      AppLogger.error('Failed to play lobby music', exception: e);
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
    }
  }

  @override
  void onTypingStatusChanged(String senderId, bool isTyping) {
    _typingStatusMap[senderId] = isTyping;
    if (!_chatController.isClosed) {
      _chatController.add({
        'type': 'typing_update',
        'senderId': senderId,
        'isTyping': isTyping,
      });
    }
  }

  // --- Game Related Actions (Delegated if needed, but simple ones here) ---
  @override
  Future<void> startGame({int playerCount = 5, int thinkingTimeS = 10}) async {
    AppLogger.info('Game: Requesting START_GAME');
    sendMessage({'type': 'START_GAME'});
  }

  @override
  void playCards(List<String> unitIds, UnitRank declaredRank) {
    AppLogger.info(
      'Game: Playing cards',
      data: {'count': unitIds.length, 'declaredRank': declaredRank.name},
    );
    sendMessage({
      'type': 'PLAY_CARDS',
      'data': {'cardIds': unitIds, 'declaredRank': declaredRank.name},
    });
  }

  @override
  void passTurn() {
    AppLogger.info('Game: Passing turn');
    sendMessage({'type': 'PASS'});
  }

  @override
  void raiseChallenge() {
    AppLogger.info('Game: Raising challenge');
    sendMessage({'type': 'CHALLENGE'});
  }

  @override
  void sortHand() {
    final sorted = List<Unit>.from(_currentState.myHand)
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    _currentState = _currentState.copyWith(myHand: sorted);
    if (!_stateController.isClosed) _stateController.add(_currentState);
  }

  @override
  void reorderHand(int oldIndex, int newIndex) {
    final hand = List<Unit>.from(_currentState.myHand);
    final u = hand.removeAt(oldIndex);
    hand.insert(newIndex, u);
    _currentState = _currentState.copyWith(myHand: hand);
    if (!_stateController.isClosed) _stateController.add(_currentState);
  }

  /// Request match history from server
  void requestMatchHistory() {
    sendMessage({'type': 'MATCH_HISTORY_GET'});
  }

  @override
  void signalClientReady() {
    AppLogger.sessionEvent(
      '📤 [Client-Ready] Signaling server that UI is ready',
    );
    // Locally trigger the shuffling animation immediately to hide latency
    // The server will eventually send its own 'shuffling' event, which we can debounce.
    if (!_eventController.isClosed) {
      _eventController.add(SessionEventType.shuffling);
    }
    sendMessage({'type': 'CLIENT_READY'});
  }

  @override
  void resetGameSession() {
    _friends = [];
    _gameLog.clear();
    _pNames.clear();
    _typingStatusMap.clear();
    _messageQueue.clear();
    _currentState = SessionState.initial();
    if (!_stateController.isClosed) _stateController.add(_currentState);
  }

  @override
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _authTimeoutTimer?.cancel();
    _watchdogTimer?.cancel();
    _subscription?.cancel();
    await _channel?.sink.close();
    updateConnectionStatus(ConnectionStatus.disconnected);
    await _voiceManager?.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }
}
