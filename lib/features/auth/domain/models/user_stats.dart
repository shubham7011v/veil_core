import 'package:equatable/equatable.dart';

class UserStats extends Equatable {
  final String userId;
  final String name;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final String rank;

  const UserStats({
    required this.userId,
    required this.name,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.rank = 'Novice',
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      rank: json['rank'] as String? ?? 'Novice',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'losses': losses,
      'rank': rank,
    };
  }

  double get winRate {
    if (gamesPlayed == 0) return 0.0;
    return (wins / gamesPlayed) * 100;
  }

  @override
  List<Object?> get props => [userId, name, gamesPlayed, wins, losses, rank];
}
