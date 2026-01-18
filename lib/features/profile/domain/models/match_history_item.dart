import 'package:equatable/equatable.dart';

class MatchHistoryItem extends Equatable {
  final String matchId;
  final DateTime playedAt;
  final int duration;
  final String winnerId;
  final int potAmount;
  final List<String> playerIds;

  const MatchHistoryItem({
    required this.matchId,
    required this.playedAt,
    required this.duration,
    required this.winnerId,
    required this.potAmount,
    required this.playerIds,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      matchId: json['matchId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      duration: json['duration'] as int,
      winnerId: json['winnerId'] as String,
      potAmount: json['potAmount'] as int,
      playerIds: (json['playerIds'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'playedAt': playedAt.toIso8601String(),
      'duration': duration,
      'winnerId': winnerId,
      'potAmount': potAmount,
      'playerIds': playerIds,
    };
  }

  @override
  List<Object?> get props => [
    matchId,
    playedAt,
    duration,
    winnerId,
    potAmount,
    playerIds,
  ];
}
