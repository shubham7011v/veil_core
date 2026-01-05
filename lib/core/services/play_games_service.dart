import 'dart:io';
import 'package:games_services/games_services.dart';
import 'package:flutter/foundation.dart';

class PlayGamesService {
  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  /// Logs the user into Play Games Services (Android) or Game Center (iOS).
  Future<bool> signIn() async {
    if (kIsWeb) return false;

    try {
      await GamesServices.signIn();
      _isSignedIn = true;
      return true;
    } catch (e) {
      debugPrint('Play Games Sign-In Error: $e');
      _isSignedIn = false;
      return false;
    }
  }

  /// Silently signs in the user.
  Future<bool> signInSilently() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      // games_services doesn't have a specific silent sign-in method that differs from signIn
      // but usually the first call to signIn handles silent sign-in if possible.
      await GamesServices.signIn();
      _isSignedIn = true;
      return true;
    } catch (e) {
      _isSignedIn = false;
      return false;
    }
  }

  /// Displays the achievements screen.
  Future<void> showAchievements() async {
    if (kIsWeb) return;
    try {
      await GamesServices.showAchievements();
    } catch (e) {
      debugPrint('Error showing achievements: $e');
    }
  }

  /// Displays the leaderboard screen.
  Future<void> showLeaderboards({String? leaderboardId}) async {
    if (kIsWeb) return;
    try {
      await GamesServices.showLeaderboards(
        iOSLeaderboardID: leaderboardId,
        androidLeaderboardID: leaderboardId,
      );
    } catch (e) {
      debugPrint('Error showing leaderboards: $e');
    }
  }

  /// Submits a score to a leaderboard.
  Future<void> submitScore({
    required int score,
    required String leaderboardId,
  }) async {
    if (kIsWeb) return;
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardId,
          iOSLeaderboardID: leaderboardId,
          value: score,
        ),
      );
    } catch (e) {
      debugPrint('Error submitting score: $e');
    }
  }

  /// Unlocks an achievement.
  Future<void> unlockAchievement({required String achievementId}) async {
    if (kIsWeb) return;
    try {
      await GamesServices.unlock(
        achievement: Achievement(
          androidID: achievementId,
          iOSID: achievementId,
        ),
      );
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
    }
  }

  /// Increments an achievement (Android only).
  Future<void> incrementAchievement({
    required String achievementId,
    required int steps,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await GamesServices.increment(
        achievement: Achievement(androidID: achievementId, steps: steps),
      );
    } catch (e) {
      debugPrint('Error incrementing achievement: $e');
    }
  }
}
