class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final int goal;
  final int reward;
  final String type;
  final int current;
  final bool completed;
  final bool isClaimed;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.reward,
    required this.type,
    required this.current,
    required this.completed,
    required this.isClaimed,
  });

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      goal: json['goal'] as int,
      reward: json['reward'] as int,
      type: json['type'] as String,
      current: json['current'] as int,
      completed: json['completed'] as bool,
      isClaimed: json['isClaimed'] as bool,
    );
  }

  double get progress => (current / goal).clamp(0.0, 1.0);
}
