import 'unit.dart';

class GameMove {
  final String playerId;
  final UnitRank declaredRank;
  final List<Unit> actualUnits;

  GameMove({
    required this.playerId,
    required this.declaredRank,
    required this.actualUnits,
  });
}
