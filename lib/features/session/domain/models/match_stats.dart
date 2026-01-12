class MatchStats {
  final int totalTurns;
  final int totalChallenges;
  final int totalCardsPlayed;
  final Duration matchDuration;

  const MatchStats({
    this.totalTurns = 0,
    this.totalChallenges = 0,
    this.totalCardsPlayed = 0,
    this.matchDuration = Duration.zero,
  });

  MatchStats copyWith({
    int? totalTurns,
    int? totalChallenges,
    int? totalCardsPlayed,
    Duration? matchDuration,
  }) {
    return MatchStats(
      totalTurns: totalTurns ?? this.totalTurns,
      totalChallenges: totalChallenges ?? this.totalChallenges,
      totalCardsPlayed: totalCardsPlayed ?? this.totalCardsPlayed,
      matchDuration: matchDuration ?? this.matchDuration,
    );
  }

  String get formattedDuration {
    final minutes = matchDuration.inMinutes;
    final seconds = matchDuration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  @override
  String toString() =>
      'MatchStats(turns: $totalTurns, challenges: $totalChallenges, cards: $totalCardsPlayed, duration: $formattedDuration)';
}
