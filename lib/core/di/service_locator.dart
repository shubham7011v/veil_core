import 'package:shared_preferences/shared_preferences.dart';
import '../data/data.dart';
import '../services/services.dart';
import '../engine/engine.dart';
import '../engine/data/handlers/websocket_session_handler.dart';
import '../services/system_status_service.dart';
import '../../features/auth/auth.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final NavigationService navigationService;
  late final StorageService storageService;
  late final AuthRepository authRepository;
  late final UserRepository userRepository;
  late final OnboardingRepository onboardingRepository;
  late final GameSessionHandler gameSessionHandler;
  late final GreetingService greetingService;
  late final SystemStatusService systemStatusService;

  // Explicitly expose WebSocket handler for specialized calls (like updateNickname)
  late final WebSocketSessionHandler _webSocketHandler;

  WebSocketSessionHandler get webSocketSessionHandler => _webSocketHandler;

  Future<void> setup() async {
    final prefs = await SharedPreferences.getInstance();

    navigationService = NavigationService();
    storageService = StorageService(prefs);
    greetingService = GreetingService();

    authRepository = AuthRepository();
    userRepository = UserRepository();
    onboardingRepository = OnboardingRepository(prefs);

    // Initialize the singleton WS handler
    _webSocketHandler = WebSocketSessionHandler();

    // Default to local, but the app can switch
    gameSessionHandler = LocalBotSessionHandler();
  }

  void initializeSystemStatus(AuthBloc authBloc) {
    systemStatusService = SystemStatusService(
      sessionHandler: _webSocketHandler,
      authBloc: authBloc,
    );
  }

  /// Factory method to create session handler based on mode
  GameSessionHandler createSessionHandler({bool online = false}) {
    if (online) {
      return _webSocketHandler;
    }
    return LocalBotSessionHandler();
  }
}

final sl = ServiceLocator();
