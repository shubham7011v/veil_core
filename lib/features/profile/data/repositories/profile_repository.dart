import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/match_history_item.dart';
import '../../../auth/domain/models/user_stats.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../../core/config/app_config.dart';

class ProfileRepository {
  final WebSocketSessionHandler _handler;

  ProfileRepository(this._handler);

  /// Get a user's profile by their ID
  Future<UserProfile> getProfile(String userId) async {
    // For MVP, we'll use the current user's data if it's their own profile
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == userId;

    if (isOwnProfile && currentUser != null) {
      // Use cached stats from WebSocket handler if available
      final stats =
          _handler.lastStats ??
          const UserStats(
            userId: '',
            name: '',
            gamesPlayed: 0,
            wins: 0,
            losses: 0,
            rank: 'Novice',
            coins: 1000,
          );

      return UserProfile(
        userId: currentUser.uid,
        name: currentUser.displayName ?? 'Unknown',
        photoUrl: currentUser.photoURL,
        bio: null, // Not implemented yet
        stats: stats,
        isOnline: true,
        isFriend: false,
        joinedDate: currentUser.metadata.creationTime ?? DateTime.now(),
      );
    }

    // For other users, fetch from backend API
    try {
      final url = Uri.parse('${AppConfig.instance.apiBaseUrl}/users/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Check if friend
        final isFriend = await this.isFriend(userId);

        return UserProfile(
          userId: userId,
          name: data['name'] ?? 'Unknown',
          photoUrl: data['photoUrl'],
          bio: data['bio'],
          stats: UserStats.fromJson(data['stats'] ?? {}),
          isOnline: data['isOnline'] ?? false,
          isFriend: isFriend,
          joinedDate: DateTime.parse(
            data['createdAt'] ?? DateTime.now().toIso8601String(),
          ),
        );
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback for demo / offline
      return UserProfile(
        userId: userId,
        name: 'Player',
        photoUrl: null,
        bio: 'Could not load profile.',
        stats: const UserStats(
          userId: '',
          name: '',
          gamesPlayed: 0,
          wins: 0,
          losses: 0,
          rank: '?',
          coins: 0,
        ),
        isOnline: false,
        isFriend: false,
        joinedDate: DateTime.now(),
      );
    }
  }

  /// Check if a user is your friend
  Future<bool> isFriend(String userId) async {
    return _handler.currentFriends.any((f) => f.friendId == userId);
  }

  /// Add a user as a friend
  Future<void> addFriend(String userId) async {
    _handler.addFriend(userId);
  }

  /// Remove a friend
  Future<void> removeFriend(String userId) async {
    _handler.removeFriend(userId);
  }

  // --- Match History ---

  Stream<List<MatchHistoryItem>> get myMatchHistoryStream =>
      _handler.matchHistoryController.stream;

  Future<void> fetchMyMatchHistory() async {
    _handler.requestMatchHistory();
  }
}
