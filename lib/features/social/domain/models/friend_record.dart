class FriendRecord {
  final String userId;
  final String friendId;
  final String status;
  final String name;
  final String rank;
  final DateTime lastSeen;
  final bool isOnline;

  FriendRecord({
    required this.userId,
    required this.friendId,
    required this.status,
    required this.name,
    required this.rank,
    required this.lastSeen,
    required this.isOnline,
  });

  factory FriendRecord.fromJson(Map<String, dynamic> json) {
    return FriendRecord(
      userId: json['userId'] as String,
      friendId: json['friendId'] as String,
      status: json['status'] as String,
      name: json['name'] as String,
      rank: json['rank'] as String,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      isOnline: json['isOnline'] as bool,
    );
  }
}
