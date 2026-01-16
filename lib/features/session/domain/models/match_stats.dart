class MatchStats {
  final int totalTurns;
  final int totalChallenges;
  final int totalCardsPlayed;
  final int bluffsCaught;
  final int falseAlarms;
  final int successfulBluffs;
  final int bluffsCaughtByOthers; // Times I was caught
  final Duration matchDuration;

  const MatchStats({
    this.totalTurns = 0,
    this.totalChallenges = 0,
    this.totalCardsPlayed = 0,
    this.bluffsCaught = 0,
    this.falseAlarms = 0,
    this.successfulBluffs = 0,
    this.bluffsCaughtByOthers = 0,
    this.matchDuration = Duration.zero,
  });

  MatchStats copyWith({
    int? totalTurns,
    int? totalChallenges,
    int? totalCardsPlayed,
    int? bluffsCaught,
    int? falseAlarms,
    int? successfulBluffs,
    int? bluffsCaughtByOthers,
    Duration? matchDuration,
  }) {
    return MatchStats(
      totalTurns: totalTurns ?? this.totalTurns,
      totalChallenges: totalChallenges ?? this.totalChallenges,
      totalCardsPlayed: totalCardsPlayed ?? this.totalCardsPlayed,
      bluffsCaught: bluffsCaught ?? this.bluffsCaught,
      falseAlarms: falseAlarms ?? this.falseAlarms,
      successfulBluffs: successfulBluffs ?? this.successfulBluffs,
      bluffsCaughtByOthers: bluffsCaughtByOthers ?? this.bluffsCaughtByOthers,
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
