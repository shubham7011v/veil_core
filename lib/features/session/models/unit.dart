import 'package:equatable/equatable.dart';

enum UnitType { spades, hearts, diamonds, clubs }

enum UnitRank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

class Unit extends Equatable {
  final String id;
  final UnitType type;
  final UnitRank rank;
  final bool isSelected;

  const Unit({
    required this.id,
    required this.type,
    required this.rank,
    this.isSelected = false,
  });

  @override
  List<Object?> get props => [id, type, rank, isSelected];

  String get label {
    return '${rank.name[0].toUpperCase()}${rank.name.substring(1)} of ${type.name}';
  }
}
