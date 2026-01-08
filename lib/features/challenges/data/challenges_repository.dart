import '../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../domain/models/daily_challenge.dart';

class ChallengesRepository {
  final WebSocketSessionHandler _handler;

  ChallengesRepository(this._handler);

  Stream<List<DailyChallenge>> get challengesStream =>
      _handler.challengesStream;
  Stream<Map<String, dynamic>> get claimResultStream =>
      _handler.challengeClaimResultStream;

  void fetchChallenges() {
    _handler.requestChallenges();
  }

  void claimReward(String challengeId) {
    _handler.claimChallenge(challengeId);
  }
}
