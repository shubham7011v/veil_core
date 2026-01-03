import 'package:shared_preferences/shared_preferences.dart';
import '../data/data.dart';
import '../services/services.dart';
import '../engine/engine.dart';

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

  Future<void> setup() async {
    final prefs = await SharedPreferences.getInstance();

    navigationService = NavigationService();
    storageService = StorageService(prefs);

    authRepository = AuthRepository();
    userRepository = UserRepository();
    onboardingRepository = OnboardingRepository(prefs);
    gameSessionHandler = LocalBotSessionHandler();
  }
}

final sl = ServiceLocator();
