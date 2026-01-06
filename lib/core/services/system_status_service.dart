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

  SystemStatus _currentStatus = SystemStatus.syncing();
  SystemStatus get currentStatus => _currentStatus;

  StreamSubscription? _sessionSub;
  StreamSubscription? _authSub;
  Timer? _connectivityTimer;

  SystemStatusService({
    required WebSocketSessionHandler sessionHandler,
    required AuthBloc authBloc,
  }) : _sessionHandler = sessionHandler,
       _authBloc = authBloc {
    _init();
  }

  void _init() {
    _sessionSub = _sessionHandler.connectionStatusStream.listen(
      (_) => _updateStatus(),
    );
    _authSub = _authBloc.stream.listen((_) => _updateStatus());

    // Periodically check internet connectivity to distinguish between local and server issues
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateStatus(),
    );

    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final gameStatus = _sessionHandler.connectionStatus;
    final authState = _authBloc.state;

    // 1. Check Internet Connectivity first
    bool hasInternet = await _checkInternet();
    if (!hasInternet) {
      _emit(SystemStatus.noInternet());
      return;
    }

    // 2. Check Auth Status
    if (authState is AuthLoading || authState is AuthInitial) {
      _emit(SystemStatus.syncing());
      return;
    }

    if (authState is AuthFailure || authState is Unauthenticated) {
      _emit(SystemStatus.authIssue());
      return;
    }

    // 3. Handle Game Server Status explicitly
    switch (gameStatus) {
      case ConnectionStatus.connected:
        _emit(SystemStatus.healthy());
        break;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        _emit(SystemStatus.syncing());
        break;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.failed:
        _emit(SystemStatus.serverDown());
        break;
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _emit(SystemStatus status) {
    if (_currentStatus.type == status.type) return;
    _currentStatus = status;
    _statusController.add(status);
  }

  void dispose() {
    _sessionSub?.cancel();
    _authSub?.cancel();
    _connectivityTimer?.cancel();
    _statusController.close();
  }
}
