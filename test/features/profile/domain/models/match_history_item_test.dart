import 'package:flutter_test/flutter_test.dart';
import 'package:veil_core/features/profile/domain/models/match_history_item.dart';

void main() {
  group('MatchHistoryItem', () {
    test('fromJson and toJson', () {
      final json = {
        'matchId': 'm1',
        'playedAt': '2023-01-01T12:00:00.000',
        'duration': 120,
        'winnerId': 'u1',
        'potAmount': 500,
        'playerIds': ['u1', 'u2'],
      };

      final item = MatchHistoryItem.fromJson(json);

      expect(item.matchId, 'm1');
      expect(item.playedAt, DateTime(2023, 1, 1, 12, 0, 0));
      expect(item.duration, 120);
      expect(item.winnerId, 'u1');
      expect(item.potAmount, 500);
      expect(item.playerIds, ['u1', 'u2']);

      final toJson = item.toJson();
      expect(toJson['matchId'], 'm1');
      expect(toJson['playedAt'], '2023-01-01T12:00:00.000');
    });
  });
}
