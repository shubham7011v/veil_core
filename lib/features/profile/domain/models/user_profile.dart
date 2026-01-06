import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_stats.dart';

class UserProfile extends Equatable {
  final String userId;
  final String name;
  final String? photoUrl;
  final String? bio;
  final UserStats stats;
  final bool isOnline;
  final bool isFriend;
  final DateTime joinedDate;

  const UserProfile({
    required this.userId,
    required this.name,
    this.photoUrl,
    this.bio,
    required this.stats,
    required this.isOnline,
    required this.isFriend,
    required this.joinedDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>),
      isOnline: json['isOnline'] as bool? ?? false,
      isFriend: json['isFriend'] as bool? ?? false,
      joinedDate: DateTime.parse(json['joinedDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'photoUrl': photoUrl,
      'bio': bio,
      'stats': stats.toJson(),
      'isOnline': isOnline,
      'isFriend': isFriend,
      'joinedDate': joinedDate.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    userId,
    name,
    photoUrl,
    bio,
    stats,
    isOnline,
    isFriend,
    joinedDate,
  ];
}
