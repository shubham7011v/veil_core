
enum UnitType {
  spades, hearts, diamonds, clubs, joker
}

enum UnitRank {
  two, three, four, five, six, seven, eight, nine, ten,
  jack, queen, king, ace, joker
}

class Unit {
  final String id;
  final UnitType type;
  final UnitRank rank;
  bool isSelected;

  Unit({
    required this.id,
    required this.type,
    required this.rank,
    this.isSelected = false,
  });
  
  String get label {
    if (rank == UnitRank.joker) return 'Joker';
    return '${rank.name[0].toUpperCase()}${rank.name.substring(1)} of ${type.name}';
  }
}
