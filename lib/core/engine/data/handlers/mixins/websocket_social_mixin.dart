import 'websocket_handler_base.dart';

/// Mixin that handles social and competitive features for WebSocket handler.
/// Includes friends, leaderboard, chat, challenges, and account management.
mixin WebSocketSocialMixin on WebSocketHandlerBase {
  // -- Social & Competitive Methods --

  /// Request coins refill from server
  void refillCoins() {
    sendMessage({'type': 'REFILL_COINS'});
  }

  /// Request leaderboard data from server
  void requestLeaderboard() {
    sendMessage({'type': 'LEADERBOARD_GET'});
  }

  /// Request friends list from server
  void requestFriends() {
    sendMessage({'type': 'FRIEND_LIST'});
  }

  /// Send a friend request to another user
  void addFriend(String friendId) {
    sendMessage({'type': 'FRIEND_REQUEST', 'data': friendId});
  }

  /// Accept a pending friend request
  void acceptFriend(String friendId) {
    sendMessage({'type': 'FRIEND_ACCEPT', 'data': friendId});
  }

  /// Remove a friend from friends list
  void removeFriend(String friendId) {
    sendMessage({'type': 'FRIEND_REMOVE', 'data': friendId});
  }

  /// Request to delete user account
  void deleteAccount() {
    sendMessage({'type': 'DELETE_ACCOUNT'});
  }

  // -- Chat Methods --

  /// Send a chat message in the current room
  void sendChatMessage(String message) {
    sendMessage({
      'type': 'CHAT',
      'data': {'message': message},
    });
  }

  /// Send an emoji reaction in the current room
  void sendEmojiMessage(String emojiId) {
    sendMessage({
      'type': 'EMOJI',
      'data': {'emojiId': emojiId},
    });
  }

  /// Update typing status for chat
  void setTypingStatus(bool isTyping) {
    sendMessage({
      'type': 'TYPING',
      'data': {'isTyping': isTyping},
    });
  }

  // -- Challenge Methods --

  /// Request daily challenges from server
  void requestChallenges() {
    sendMessage({'type': 'CHALLENGES_GET'});
  }

  /// Claim a completed challenge reward
  void claimChallenge(String challengeId) {
    sendMessage({'type': 'CHALLENGE_CLAIM', 'data': challengeId});
  }
}
