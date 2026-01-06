import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class ErrorMessages {
  static String getFromException(dynamic e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Access denied. Please sign in again.';
        case 'unavailable':
          return 'The connection to the server is weak. Check your internet.';
        case 'not-found':
          return 'Could not find your session...';
        default:
          return 'A mysterious error has occurred. Please try again.';
      }
    }

    final detail = kDebugMode ? ': $e' : '';
    return 'The server is currently busy. Please try again later.$detail';
  }
}
