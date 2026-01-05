import 'package:shared_preferences/shared_preferences.dart';
import '../data/data.dart';
import '../services/services.dart';
import '../engine/engine.dart';
import '../engine/data/handlers/websocket_session_handler.dart';

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
  late final PlayGamesService playGamesService;

  Future<void> setup() async {
    final prefs = await SharedPreferences.getInstance();

    navigationService = NavigationService();
    storageService = StorageService(prefs);
    playGamesService = PlayGamesService();

    authRepository = AuthRepository();
    userRepository = UserRepository();
    onboardingRepository = OnboardingRepository(prefs);
    gameSessionHandler = createSessionHandler(online: false);
  }

  /// Factory method to create session handler based on mode
  GameSessionHandler createSessionHandler({bool online = false}) {
    if (online) {
      return WebSocketSessionHandler();
    }
    return LocalBotSessionHandler();
  }
}

final sl = ServiceLocator();
