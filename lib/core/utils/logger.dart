import 'package:flutter/foundation.dart';

enum LogLevel { info, warn, error }

/// Lightweight structured logger wrapping debugPrint.
class AppLogger {
  AppLogger._();

  static void _log(LogLevel level, String tag, String message, [Object? error]) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = '[${level.name.toUpperCase()}]';
    debugPrint('$prefix $timestamp [$tag] $message');
    if (error != null) {
      debugPrint('$prefix $timestamp [$tag] Error: $error');
    }
  }

  static void info(String tag, String message) => _log(LogLevel.info, tag, message);
  static void warn(String tag, String message) => _log(LogLevel.warn, tag, message);
  static void error(String tag, String message, [Object? error]) =>
      _log(LogLevel.error, tag, message, error);
}
