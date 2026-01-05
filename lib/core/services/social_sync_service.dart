import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/domain/handlers/game_session_handler.dart';
import '../../features/auth/domain/models/user_stats.dart';
import 'play_games_service.dart';

class SocialSyncService {
  final GameSessionHandler _sessionHandler;
  final PlayGamesService _playGamesService;
  StreamSubscription? _subscription;

  SocialSyncService({
    required GameSessionHandler sessionHandler,
    required PlayGamesService playGamesService,
  }) : _sessionHandler = sessionHandler,
       _playGamesService = playGamesService;

  void init() {
    _subscription?.cancel();
    _subscription = _sessionHandler.statsStream.listen(_handleStatsUpdate);
  }

  void _handleStatsUpdate(dynamic data) {
    if (data is! UserStats) return;

    final stats = data;
    debugPrint('SocialSync: Handling stats update for ${stats.userId}');

    // 1. Submit to Play Games Leaderboard (Android/iOS native)
    // We use a general 'global_leaderboard' ID, though specific ones can be used.
    _playGamesService.submitScore(
      score: stats.wins,
      leaderboardId: 'global_leaderboard',
    );

    // 2. Unlock Achievements based on milestones
    _checkAchievements(stats);
  }

  void _checkAchievements(UserStats stats) {
    // Milestone: First Win
    if (stats.wins >= 1) {
      _playGamesService.unlockAchievement(achievementId: 'first_victory');
    }

    // Milestone: Apprentice (5 wins)
    if (stats.wins >= 5) {
      _playGamesService.unlockAchievement(achievementId: 'apprentice_rank');
    }

    // Milestone: Expert (50 wins)
    if (stats.wins >= 50) {
      _playGamesService.unlockAchievement(achievementId: 'expert_rank');
    }

    // Milestone: Card Shark (100 games played)
    if (stats.gamesPlayed >= 100) {
      _playGamesService.unlockAchievement(achievementId: 'card_shark');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
