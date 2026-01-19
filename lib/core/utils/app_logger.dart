import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Centralized logging utility for the application
class AppLogger {
  static const _enableLogging = kDebugMode;
  static File? _logFile;
  static IOSink? _sink;

  /// Initializes file logging. On Windows, saves to the project logs directory.
  static Future<void> initFileLogging() async {
    if (!_enableLogging) return;

    try {
      final now = DateTime.now();
      final formatter = DateFormat('yyyyMMdd_HHmm');
      final fileName = 'session_${formatter.format(now)}.log';

      String logDirPath;

      if (Platform.isWindows) {
        // Direct path for Windows development as requested
        logDirPath = r'c:\Users\u32n08\Documents\veil_core\logs';
      } else {
        // Fallback for other platforms (would ideally use path_provider if needed)
        // For now, we only implement the specific Windows request
        return;
      }

      final dir = Directory(logDirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      _logFile = File('${dir.path}/$fileName');
      _sink = _logFile!.openWrite(mode: FileMode.append);

      info('File logging initialized at: ${_logFile!.path}');
    } catch (e) {
      debugPrint('Failed to initialize file logging: $e');
    }
  }

  static void _writeToLog(
    String label,
    String message, {
    Map<String, dynamic>? data,
  }) {
    if (!_enableLogging) return;

    final timestamp = DateTime.now().toIso8601String();
    final logLine =
        '[$timestamp] $label: $message ${data != null ? '- $data' : ''}';

    // Console output
    debugPrint(logLine);

    // File output
    _sink?.writeln(logLine);
  }

  // Session-related logs
  static void sessionEvent(String event, {Map<String, dynamic>? data}) {
    _writeToLog('SESSION', event, data: data);
  }

  static void sessionError(
    String error, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    _writeToLog('SESSION ERROR', error);
    if (exception != null) _writeToLog('EXCEPTION', exception.toString());
    if (stackTrace != null) _writeToLog('STACKTRACE', stackTrace.toString());
  }

  // Voice-related logs
  static void voiceEvent(String event, {Map<String, dynamic>? data}) {
    _writeToLog('VOICE', event, data: data);
  }

  static void voiceError(String error, {Object? exception}) {
    if (!_enableLogging) return;
    _writeToLog('VOICE ERROR', error);
    if (exception != null) _writeToLog('EXCEPTION', exception.toString());
  }

  // Network-related logs
  static void networkEvent(String event, {Map<String, dynamic>? data}) {
    _writeToLog('NETWORK', event, data: data);
  }

  static void networkError(String error, {Object? exception}) {
    if (!_enableLogging) return;
    _writeToLog('NETWORK ERROR', error);
    if (exception != null) _writeToLog('EXCEPTION', exception.toString());
  }

  // Bot-related logs (for debugging local bot behavior)
  static void botEvent(
    String botId,
    String event, {
    Map<String, dynamic>? data,
  }) {
    _writeToLog('BOT[$botId]', event, data: data);
  }

  // General logs
  static void info(String message, {Map<String, dynamic>? data}) {
    _writeToLog('INFO', message, data: data);
  }

  static void warning(
    String message, {
    Object? exception,
    Map<String, dynamic>? data,
  }) {
    if (!_enableLogging) return;
    _writeToLog('WARNING', message, data: data);
    if (exception != null) _writeToLog('EXCEPTION', exception.toString());
  }

  static void error(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    _writeToLog('ERROR', message);
    if (exception != null) _writeToLog('EXCEPTION', exception.toString());
    if (stackTrace != null) _writeToLog('STACKTRACE', stackTrace.toString());
  }

  // Performance tracking
  static void performance(String operation, Duration duration) {
    _writeToLog('PERFORMANCE', '$operation took ${duration.inMilliseconds}ms');
  }

  /// Closes the log file sink
  static Future<void> dispose() async {
    await _sink?.close();
    _sink = null;
  }
}
