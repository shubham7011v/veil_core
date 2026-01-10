import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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

    // Report to Crashlytics if Firebase is initialized
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
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
