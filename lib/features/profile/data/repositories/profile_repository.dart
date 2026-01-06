import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/user_profile.dart';
import '../../../auth/domain/models/user_stats.dart';
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';

class ProfileRepository {
  final WebSocketSessionHandler _handler;

  ProfileRepository(this._handler);

  /// Get a user's profile by their ID
  Future<UserProfile> getProfile(String userId) async {
    // For now, we'll construct profile from available data
    // In the future, this should call a backend API endpoint

    // Get user stats from the handler's stats stream
    // This is a simplified implementation - ideally the backend
    // would have a GET /api/profile/:userId endpoint

    // For MVP, we'll use the current user's data if it's their own profile
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == userId;

    if (isOwnProfile && currentUser != null) {
      // Return own profile - we have this data
      return UserProfile(
        userId: currentUser.uid,
        name: currentUser.displayName ?? 'Unknown',
        photoUrl: currentUser.photoURL,
        bio: null, // Not implemented yet
        stats: const UserStats(
          userId: '',
          name: '',
          gamesPlayed: 0,
          wins: 0,
          losses: 0,
          rank: 'Novice',
          coins: 1000,
        ), // TODO: Get from AuthBloc
        isOnline: true,
        isFriend: false,
        joinedDate: currentUser.metadata.creationTime ?? DateTime.now(),
      );
    }

    // For other users, we need to fetch from backend
    // TODO: Implement backend API call
    throw UnimplementedError('Backend profile API not yet implemented');
  }

  /// Check if a user is your friend
  Future<bool> isFriend(String userId) async {
    // TODO: Query friends list from handler
    // For now, return false
    return false;
  }

  /// Add a user as a friend
  Future<void> addFriend(String userId) async {
    _handler.addFriend(userId);
  }

  /// Remove a friend
  Future<void> removeFriend(String userId) async {
    // TODO: Implement remove friend in handler
    throw UnimplementedError('Remove friend not yet implemented');
  }
}
