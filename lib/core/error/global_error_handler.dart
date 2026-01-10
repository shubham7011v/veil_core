import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

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
  static void run(FutureOr<void> Function() appRunner) {
    // Ensure bindings are initialized before entering the zone
    WidgetsFlutterBinding.ensureInitialized();

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

        await appRunner();
      },
      (error, stack) {
        handle(error, stack);
      },
    );
  }
}
