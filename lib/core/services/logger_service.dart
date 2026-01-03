import 'dart:developer' as dev;

class LoggerService {
  static void log(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    dev.log(message, name: tag ?? 'APP', error: error, stackTrace: stackTrace);
  }

  static void info(String message, [String? tag]) =>
      log('INFO: $message', tag: tag);
  static void warning(String message, [String? tag]) =>
      log('WARNING: $message', tag: tag);
  static void error(String message, [Object? e, StackTrace? st, String? tag]) =>
      log('ERROR: $message', tag: tag, error: e, stackTrace: st);
}
