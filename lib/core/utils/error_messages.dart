import 'package:firebase_core/firebase_core.dart';

class ErrorMessages {
  static String getFromException(dynamic e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'The Royal Court requires your signature. Please sign in again.';
        case 'unavailable':
          return 'The connection to the Court is weak. Check your internet.';
        case 'not-found':
          return 'Searching for your seat in the court...';
        default:
          return 'A mysterious error has occurred. Please try again.';
      }
    }

    final message = e.toString().toLowerCase();
    if (message.contains('network')) {
      return 'The connection to the Court is weak. Check your internet.';
    }

    return 'The Royal Court is currently busy. Please try again later.';
  }
}
