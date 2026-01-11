import 'package:flutter_test/flutter_test.dart';
import 'package:veil_core/core/error/failure.dart';

void main() {
  group('Failure Error Display Tests', () {
    test('Failure.toString() should return message', () {
      const failure = ServerFailure('Server is down');
      expect(failure.toString(), equals('Server is down'));
    });

    test('NetworkFailure.toString() should return message', () {
      const failure = NetworkFailure('No internet connection');
      expect(failure.toString(), equals('No internet connection'));
    });

    test('AuthFailure.toString() should return message', () {
      const failure = AuthFailure('Invalid credentials');
      expect(failure.toString(), equals('Invalid credentials'));
    });

    test('UnknownFailure.toString() should return default message', () {
      const failure = UnknownFailure();
      expect(
        failure.toString(),
        equals('Something went wrong. We are looking into it.'),
      );
    });

    test('Custom error message in UnknownFailure', () {
      const failure = UnknownFailure('Custom error occurred');
      expect(failure.toString(), equals('Custom error occurred'));
    });

    test('Failure with originalError should still return message', () {
      const originalError = 'Original exception details';
      const failure = ServerFailure('Connection timeout', originalError);

      expect(failure.toString(), equals('Connection timeout'));
      expect(failure.originalError, equals(originalError));
    });

    test('All Failure subclasses properly override toString', () {
      final failures = [
        const ServerFailure('Server error'),
        const NetworkFailure('Network error'),
        const AuthFailure('Auth error'),
        const CacheFailure('Cache error'),
        const UnknownFailure('Unknown error'),
        const SessionFailure('Session error'),
      ];

      for (final failure in failures) {
        // Ensure toString() doesn't return "Instance of 'xxx'"
        final str = failure.toString();
        expect(
          str.startsWith('Instance of'),
          isFalse,
          reason: 'Failure toString() should not return "Instance of"',
        );
        expect(
          str,
          isNotEmpty,
          reason: 'Failure toString() should return non-empty message',
        );
      }
    });
  });
}
