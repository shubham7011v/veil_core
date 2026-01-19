import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/app_logger.dart';

class AuthRepository {
  FirebaseAuth? _firebaseAuthInstance;
  GoogleSignIn? _googleSignInInstance;

  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuthInstance = firebaseAuth,
      _googleSignInInstance = googleSignIn;

  FirebaseAuth get _firebaseAuth =>
      _firebaseAuthInstance ??= FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    AppLogger.info('Auth: Starting Google Sign-In');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);
      AppLogger.info(
        'Auth: Google Sign-In Success',
        data: {'uid': result.user?.uid},
      );
      return result;
    } catch (e) {
      AppLogger.error('Auth: Google Sign-In Failed', exception: e);
      rethrow;
    }
  }

  Future<UserCredential?> signInSilently() async {
    AppLogger.info('Auth: Attempting Silent Sign-In');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);
      AppLogger.info(
        'Auth: Silent Sign-In Success',
        data: {'uid': result.user?.uid},
      );
      return result;
    } catch (e) {
      AppLogger.info('Auth: Silent Sign-In Failed/Not available');
      return null;
    }
  }

  Future<void> signOut() async {
    AppLogger.info('Auth: Signing out');
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> reauthenticate() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Re-authentication aborted by user',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      try {
        await user.delete();
        await _googleSignIn.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // Re-authenticate and try again
          await reauthenticate();
          await user.delete();
          await _googleSignIn.signOut();
        } else {
          rethrow;
        }
      }
    }
  }
}
