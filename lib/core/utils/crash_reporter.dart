import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash reporting service backed by Sentry.
///
/// Usage in main.dart:
///   await CrashReporter.init(Env.sentryDsn);
///   CrashReporter.guard(() => runApp(const MyApp()));
///
/// Init is a no-op in debug mode and when the DSN is empty (dev builds
/// without a Sentry project). When init is skipped, every [report] call
/// becomes a debug-only print — the FlutterError / PlatformDispatcher /
/// ErrorWidget hooks installed in main.dart will still fire but quietly
/// drop events instead of paying for them.
class CrashReporter {
  static bool _initialized = false;

  /// Whether Sentry was successfully initialised. Exposed for diagnostics
  /// (e.g. an in-app debug screen showing whether crash reporting is live
  /// for this build).
  static bool get isInitialized => _initialized;

  /// Initialize crash reporting. No-op in debug mode or when [dsn] is empty.
  static Future<void> init(String dsn) async {
    if (kDebugMode) return;
    if (dsn.isEmpty) return;
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
