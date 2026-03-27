import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash reporting service backed by Sentry.
///
/// Usage in main.dart:
///   await CrashReporter.init('YOUR_SENTRY_DSN');
///   CrashReporter.guard(() => runApp(const MyApp()));
class CrashReporter {
  static bool _initialized = false;

  /// Initialize crash reporting. No-op in debug mode.
  static Future<void> init(String dsn) async {
    if (kDebugMode) return;
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'production' : 'staging';
    });
    _initialized = true;
  }

  /// Reports an exception to Sentry.
  static Future<void> report(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) async {
    if (kDebugMode) {
      debugPrint('CrashReporter: $error\n$stackTrace');
      return;
    }
    if (!_initialized) return;
    await Sentry.captureException(error, stackTrace: stackTrace);
  }

  /// Wraps app startup to catch uncaught exceptions.
  static Future<void> guard(Future<void> Function() appRunner) async {
    await runZonedGuarded(
      appRunner,
      (error, stack) => report(error, stack, context: 'uncaught'),
    );
  }
}
