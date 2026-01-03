import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepository {
  final SharedPreferences _prefs;
  static const String _hasSeenIntroKey = 'has_seen_intro';

  OnboardingRepository(this._prefs);

  bool hasSeenIntro() {
    return _prefs.getBool(_hasSeenIntroKey) ?? false;
  }

  Future<void> markIntroAsSeen() async {
    await _prefs.setBool(_hasSeenIntroKey, true);
  }
}
