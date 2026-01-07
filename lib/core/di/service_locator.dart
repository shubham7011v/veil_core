import 'package:shared_preferences/shared_preferences.dart';
import '../data/data.dart';
import '../services/services.dart';
import '../engine/engine.dart';
import '../engine/data/handlers/websocket_session_handler.dart';
import '../repositories/session_repository.dart';
import '../repositories/websocket_session_repository.dart';
import '../services/audio/audio_service_interface.dart';
import '../services/audio/audio_service_impl.dart';
import '../services/system_status_service.dart';
import '../notifications/bloc/app_notification_bloc.dart';
import '../../features/auth/auth.dart';
import '../../features/profile/profile.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final NavigationService navigationService;
  late final StorageService storageService;
  late final AuthRepository authRepository;
  late final UserRepository userRepository;
  late final OnboardingRepository onboardingRepository;
  late final SessionRepository sessionRepository;
  late final ProfileRepository profileRepository;
  late final GameSessionHandler gameSessionHandler;
  late final VoiceSessionHandler voiceSessionHandler;
  late final GreetingService greetingService;
  late final SystemStatusService systemStatusService;
  late final AudioService audioService;
  late final AppNotificationBloc notificationBloc;

  // Explicitly expose WebSocket handler for specialized calls (like updateNickname)
  late final WebSocketSessionHandler _webSocketHandler;

  WebSocketSessionHandler get webSocketSessionHandler => _webSocketHandler;

  Future<void> setup() async {
    final prefs = await SharedPreferences.getInstance();

    navigationService = NavigationService();
    storageService = StorageService(prefs);
    greetingService = GreetingService();

    // Initialize Notification Bloc
    notificationBloc = AppNotificationBloc();

    // Initialize Audio Service
    audioService = AudioServiceImpl();
    await audioService.initialize();

    authRepository = AuthRepository();
    userRepository = UserRepository();
    onboardingRepository = OnboardingRepository(prefs);

    // Initialize the singleton WS handler
    _webSocketHandler = WebSocketSessionHandler();

    sessionRepository = WebSocketSessionRepository(_webSocketHandler);

    // Initialize ProfileRepository with WebSocket handler
    profileRepository = ProfileRepository(_webSocketHandler);

    // Default to local, but the app can switch
    gameSessionHandler = LocalBotSessionHandler();
    voiceSessionHandler = _webSocketHandler;
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
