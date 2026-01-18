import 'package:shared_preferences/shared_preferences.dart';
import '../config/feature_flags.dart';
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
import '../../features/challenges/data/challenges_repository.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/offline/offline.dart';
import '../../features/session/session.dart';
import '../services/notification_service.dart';

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
  late final ChallengesRepository challengesRepository;
  late final AdminRepository adminRepository;
  late final GameSessionHandler gameSessionHandler;
  late final VoiceSessionHandler? voiceSessionHandler; // Nullable when disabled
  late final GreetingService greetingService;
  late final SystemStatusService systemStatusService;
  late final AudioService audioService;
  late final AppNotificationBloc notificationBloc;
  late final NotificationService notificationService;
  late final SessionBloc sessionBloc;

  // Offline Services
  late final LocalGameEngine localGameEngine;
  late final LocalServerService localServerService;
  late final DiscoveryService discoveryService;

  // Explicitly expose WebSocket handler for specialized calls (like updateNickname)
  late final WebSocketSessionHandler _webSocketHandler;

  WebSocketSessionHandler get webSocketSessionHandler => _webSocketHandler;

  Future<void> setup() async {
    final prefs = await SharedPreferences.getInstance();

    navigationService = NavigationService();
    storageService = StorageService(prefs);
    greetingService = GreetingService();

    // Initialize the singleton WS handler
    _webSocketHandler = WebSocketSessionHandler();

    // Initialize Repositories
    authRepository = AuthRepository();
    userRepository = UserRepository();
    onboardingRepository = OnboardingRepository(prefs);
    sessionRepository = WebSocketSessionRepository(_webSocketHandler);
    profileRepository = ProfileRepository(_webSocketHandler);
    challengesRepository = ChallengesRepository(_webSocketHandler);
    adminRepository = AdminRepository();

    // Default to local, but the app can switch
    gameSessionHandler = LocalBotSessionHandler();

    // Conditionally register voice based on feature flag
    if (FeatureFlags.enableVoiceChat) {
      voiceSessionHandler = _webSocketHandler;
    } else {
      voiceSessionHandler = null; // Voice disabled
    }

    // Initialize Audio Service
    audioService = AudioServiceImpl();
    await audioService.initialize();

    // Initialize Notification Service
    notificationService = NotificationService();

    // Initialize Blocs (depend on services/repositories)
    notificationBloc = AppNotificationBloc();
    sessionBloc = SessionBloc();

    // Initialize Offline Services
    localGameEngine = LocalGameEngine();
    localServerService = LocalServerService(localGameEngine);
    discoveryService = DiscoveryService();
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
