import 'dart:async';
import 'package:flutter/foundation.dart';

/// specialized class to handle all uncaught errors in the application.
class GlobalErrorHandler {
  static void handle(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('--------------------------------');
      debugPrint('Global Error Caught:');
      debugPrint('$error');
      debugPrint('$stack');
      debugPrint('--------------------------------');
    }

    // Here we can report to Crashlytics or Sentry
    // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }

  /// Runs the app inside a protected zone.
  static void run(void Function() appRunner) {
    runZonedGuarded(
      () async {
        FlutterError.onError = (FlutterErrorDetails details) {
          if (kDebugMode) {
            FlutterError.dumpErrorToConsole(details);
          } else {
            // Forward to zone handler
            Zone.current.handleUncaughtError(details.exception, details.stack!);
          }
        };

        appRunner();
      },
      (error, stack) {
        handle(error, stack);
      },
    );
  }
}
