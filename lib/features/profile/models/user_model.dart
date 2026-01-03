import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final int coins;
  final String rank;
  final bool isNameSet;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    this.coins = 1000,
    this.rank = 'Novice',
    this.isNameSet = false,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    photoUrl,
    createdAt,
    lastLoginAt,
    coins,
    rank,
    isNameSet,
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'coins': coins,
      'rank': rank,
      'isNameSet': isNameSet,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      createdAt: DateTime.parse(map['createdAt']),
      lastLoginAt: DateTime.parse(map['lastLoginAt']),
      coins: map['coins'] ?? 1000,
      rank: map['rank'] ?? 'Novice',
      isNameSet: map['isNameSet'] ?? false,
    );
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    DateTime? lastLoginAt,
    int? coins,
    String? rank,
    bool? isNameSet,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      coins: coins ?? this.coins,
      rank: rank ?? this.rank,
      isNameSet: isNameSet ?? this.isNameSet,
    );
  }
}
