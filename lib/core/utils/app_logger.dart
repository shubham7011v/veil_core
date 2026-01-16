import 'package:flutter/foundation.dart';

/// Centralized logging utility for the application
class AppLogger {
  static const _enableLogging = kDebugMode;

  // Session-related logs
  static void sessionEvent(String event, {Map<String, dynamic>? data}) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] SESSION: $event ${data != null ? '- $data' : ''}');
  }

  static void sessionError(
    String error, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] SESSION ERROR: $error');
    if (exception != null) debugPrint('Exception: $exception');
    if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
  }

  // Voice-related logs
  static void voiceEvent(String event, {Map<String, dynamic>? data}) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] VOICE: $event ${data != null ? '- $data' : ''}');
  }

  static void voiceError(String error, {Object? exception}) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] VOICE ERROR: $error');
    if (exception != null) debugPrint('Exception: $exception');
  }

  // Network-related logs
  static void networkEvent(String event, {Map<String, dynamic>? data}) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] NETWORK: $event ${data != null ? '- $data' : ''}');
  }

  static void networkError(String error, {Object? exception}) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] NETWORK ERROR: $error');
    if (exception != null) debugPrint('Exception: $exception');
  }

  // General logs
  static void info(String message, {Map<String, dynamic>? data}) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] INFO: $message ${data != null ? '- $data' : ''}');
  }

  static void warning(
    String message, {
    Object? exception,
    Map<String, dynamic>? data,
  }) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint(
      '[$timestamp] WARNING: $message ${data != null ? '- $data' : ''}',
    );
    if (exception != null) debugPrint('Exception: $exception');
  }

  static void error(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] ERROR: $message');
    if (exception != null) debugPrint('Exception: $exception');
    if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
  }

  // Performance tracking
  static void performance(String operation, Duration duration) {
    if (!_enableLogging) return;
    final timestamp = DateTime.now().toIso8601String();
    debugPrint(
      '[$timestamp] PERFORMANCE: $operation took ${duration.inMilliseconds}ms',
    );
  }
}
