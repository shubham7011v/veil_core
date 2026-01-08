import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class ErrorMessages {
  static String getFromException(dynamic e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Access denied. Please sign in again.';
        case 'unavailable':
          return 'The connection to the server is weak. Please check your internet.';
        case 'not-found':
          return 'We could not locate your session. It may have ended.';
        default:
          return 'A mysterious error occurred. Our team is investigating.';
      }
    }

    final detail = kDebugMode ? ': $e' : '';
    return 'The server is currently occupied. Please try again in a moment.$detail';
  }
}
