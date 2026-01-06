import 'package:firebase_auth/firebase_auth.dart' as auth;

class UserRepository {
  UserRepository();

  /// No-op for now as Firestore is removed.
  /// User basic info is managed by FirebaseAuth.
  /// Game stats are managed by WebSocketSessionHandler.
  Future<void> syncUser(auth.User firebaseUser) async {
    // Migration: We no longer sync to Firestore.
    // The Go backend handles stats sync via AUTH message.
  }
}
