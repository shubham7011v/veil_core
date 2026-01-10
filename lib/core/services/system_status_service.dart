import 'dart:async';
import 'dart:io';
import '../models/system_status.dart';
import '../engine/data/handlers/websocket_session_handler.dart';
import '../../../features/auth/auth.dart';

class SystemStatusService {
  final WebSocketSessionHandler _sessionHandler;
  final AuthBloc _authBloc;

  final _statusController = StreamController<SystemStatus>.broadcast();
  Stream<SystemStatus> get statusStream => _statusController.stream;

  SystemStatus _currentStatus = SystemStatus.healthy();
  SystemStatus get currentStatus => _currentStatus;

  StreamSubscription? _sessionSub;
  StreamSubscription? _authSub;
  Timer? _connectivityTimer;
  Timer? _syncTimeout;
  int _updateVersion = 0;

  SystemStatusService({
    required WebSocketSessionHandler sessionHandler,
    required AuthBloc authBloc,
  }) : _sessionHandler = sessionHandler,
       _authBloc = authBloc {
    _init();
  }

  void _init() {
    _sessionSub = _sessionHandler.connectionStatusStream.listen((_) {
      _updateStatus();
    });
    _authSub = _authBloc.stream.listen((_) => _updateStatus());

    // Periodically check connectivity
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateStatus();
    });

    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final version = ++_updateVersion;

    // 1. Connectivity Check (Async)
    final hasInternet = await _checkInternet();

    // If a newer update has started, abort this one to prevent UI "flicker" or stale states
    if (version != _updateVersion) return;

    // Fetch latest states AFTER completing the async internet check
    final authState = _authBloc.state;
    final gameStatus = _sessionHandler.connectionStatus;

    if (!hasInternet) {
      _emit(SystemStatus.noInternet());
      return;
    }

    // 2. Auth Status
    if (authState is AuthLoading || authState is AuthInitial) {
      _emit(SystemStatus.syncing());
      return;
    }

    if (authState is AuthFailure) {
      _emit(SystemStatus.authIssue());
      return;
    }

    // 3. Handle Game Server Status
    switch (gameStatus) {
      case ConnectionStatus.connected:
        _emit(SystemStatus.healthy());
        break;
      case ConnectionStatus.connecting:
        _emit(SystemStatus.syncing());
        break;
      case ConnectionStatus.reconnecting:
        _emit(SystemStatus.reconnecting());
        break;
      case ConnectionStatus.disconnected:
        // If we are disconnected but have internet and auth, we are "Healthy" (just idle)
        _emit(SystemStatus.healthy());
        break;
      case ConnectionStatus.failed:
        _emit(SystemStatus.serverDown());
        break;
    }
  }

  Future<bool> _checkInternet() async {
    // If we are already connected to the game server, we definitely have some connectivity.
    if (_sessionHandler.connectionStatus == ConnectionStatus.connected) {
      return true;
    }

    try {
      // Use a short timeout to prevent long DNS hangs that pin the UI to "Initializing..."
      // TODO: Implement exponential backoff for these pings to reduce network load when offline
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _emit(SystemStatus status) {
    if (_currentStatus.type == status.type) return;

    // Manage Syncing Timeout
    if (status.type == SystemStatusType.syncing) {
      _syncTimeout ??= Timer(const Duration(seconds: 10), () {
        // If we are still syncing after 10 seconds, force an update to show real bottleneck
        _syncTimeout = null;
        _handleSyncTimeout();
      });
    } else {
      _syncTimeout?.cancel();
      _syncTimeout = null;
    }

    _currentStatus = status;
    _statusController.add(status);
  }

  void _handleSyncTimeout() {
    final gameStatus = _sessionHandler.connectionStatus;
    final authState = _authBloc.state;

    if (gameStatus == ConnectionStatus.connecting) {
      _emit(
        SystemStatus.serverDown(),
      ); // Assume server is unreachable if connecting > 3s
    } else if (authState is AuthLoading || authState is AuthInitial) {
      _emit(SystemStatus.authIssue()); // Assume auth is stuck
    }
  }

  void dispose() {
    _sessionSub?.cancel();
    _authSub?.cancel();
    _connectivityTimer?.cancel();
    _statusController.close();
  }
}
