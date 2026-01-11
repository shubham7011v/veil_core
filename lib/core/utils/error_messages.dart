import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

    if (e is PlatformException) {
      // Handle Google Sign-In specific errors
      if (e.code == 'sign_in_failed') {
        return 'Google Sign-In failed. Please check your network or try again.';
      }
      if (e.code == 'network_error') {
        return 'Network error occurred during sign in.';
      }
      return 'Platform Error (${e.code}): ${e.message}';
    }

    final detail = kDebugMode ? ': $e' : '';
    return 'The server is currently occupied. Please try again in a moment.$detail';
  }
}
