import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../utils/app_logger.dart';
import 'failure.dart';

/// specialized class to handle all uncaught errors in the application.
class GlobalErrorHandler {
  /// Extract a readable message from any error object
  static String _getErrorMessage(Object error) {
    // Handle Failure objects directly
    if (error is Failure) {
      return error.message;
    }

    // Try dynamic property access for obfuscated objects
    try {
      final dynamic err = error;
      final msg = err.message ?? err.failure ?? err.error ?? err.description;
      if (msg != null) return msg.toString();
    } catch (_) {}

    // Fallback to toString, but clean up "Instance of" strings
    final str = error.toString();
    if (str.startsWith('Instance of')) {
      return '${error.runtimeType}: (no message available)';
    }
    return str;
  }

  static void handle(Object error, StackTrace stack) {
    final message = _getErrorMessage(error);

    if (kDebugMode) {
      AppLogger.error('--------------------------------');
      AppLogger.error('Global Error Caught:');
      AppLogger.error(message);
      AppLogger.error('$stack');
      AppLogger.error('--------------------------------');
    }

    // Report to Crashlytics if Firebase is initialized
    if (Firebase.apps.isNotEmpty) {
      try {
        // Use recordError with reason for better crash reports
        FirebaseCrashlytics.instance.recordError(
          Exception(
            message,
          ), // Wrap in Exception so Crashlytics shows the message
          stack,
          reason: error.runtimeType.toString(),
          fatal: true,
        );
      } catch (_) {
        // Failed to report to Crashlytics, ignore to prevent recursive crashes
      }
    }
  }

  /// Runs the app inside a protected zone.
  static void run(Future<void> Function() appRunner) {
    runZonedGuarded(
      () async {
        // Ensure bindings are initialized before entering the zone
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (FlutterErrorDetails details) {
          if (kDebugMode) {
            FlutterError.dumpErrorToConsole(details);
          } else {
            // Forward to zone handler
            Zone.current.handleUncaughtError(details.exception, details.stack!);
          }
        };

        await appRunner();
      },
      (error, stack) {
        handle(error, stack);
      },
    );
  }
}
