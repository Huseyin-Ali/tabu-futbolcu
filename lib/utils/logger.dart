import 'dart:developer' as developer;

/// Uygulama genelinde kullanılacak logger utility
class AppLogger {
  static const String _tag = 'TabuFutbolcu';

  static void info(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 800, // INFO level
    );
  }

  static void warning(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 900, // WARNING level
    );
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 1000, // ERROR level
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void debug(String message, [String? tag]) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 700, // DEBUG level
    );
  }
}
