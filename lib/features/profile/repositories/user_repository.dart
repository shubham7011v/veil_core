import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<UserModel?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> syncUser(auth.User firebaseUser) async {
    final uid = firebaseUser.uid;
    final doc = await _usersCollection.doc(uid).get();

    if (doc.exists) {
      // Update last login
      await _usersCollection.doc(uid).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
        'name': firebaseUser.displayName ?? 'Player',
        'photoUrl': firebaseUser.photoURL,
      });
    } else {
      // Create new profile
      final newUser = UserModel(
        id: uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? 'Player',
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      await _usersCollection.doc(uid).set(newUser.toMap());
    }
  }

  Future<void> updateUser(UserModel user) async {
    await _usersCollection.doc(user.id).update(user.toMap());
  }
}
