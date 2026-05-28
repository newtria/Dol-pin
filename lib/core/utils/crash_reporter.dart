import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash reporting service backed by Sentry.
///
/// Usage in main.dart:
///   await CrashReporter.init(Env.sentryDsn);
///   CrashReporter.guard(() => runApp(const MyApp()));
///
/// Init outcome (skipped / failed / success) is always printed so a
/// release build silently shipping with an empty DSN — or with a Sentry
/// init that crashed — is visible in device logs rather than invisible.
/// Without the log, the wired-up FlutterError.onError hooks installed by
/// Sentry would silently drop every event.
///
/// Sentry's own integrations install FlutterError.onError and
/// PlatformDispatcher.instance.onError as part of init; callers MUST NOT
/// reassign those after init — see lib/main.dart.
class CrashReporter {
  static const _logTag = 'CrashReporter';

  static bool _initialized = false;

  /// Whether Sentry was successfully initialised.
  static bool get isInitialized => _initialized;

  /// Initialize crash reporting. No-op in debug mode or when [dsn] is empty.
  /// Sentry init failures are caught and logged — they must not crash the
  /// app's own startup.
  static Future<void> init(String dsn) async {
    if (kDebugMode) {
      debugPrint('$_logTag: skipped (debug build)');
      return;
    }
    if (dsn.isEmpty) {
      // Loud warning so a release ship with missing SENTRY_DSN doesn't
      // look healthy in Ops dashboards while actually reporting nothing.
      debugPrint('$_logTag: WARNING — SENTRY_DSN empty; crash reporting OFF');
      return;
    }
    try {
      await SentryFlutter.init((options) {
        options.dsn = dsn;
        options.tracesSampleRate = 0.2;
        options.environment = kReleaseMode ? 'production' : 'staging';
      });
      _initialized = true;
      debugPrint('$_logTag: initialized');
    } catch (e, st) {
      // If Sentry itself blew up at init, we cannot Sentry-report it —
      // but at least surface it in device logs and (if available) via
      // Sentry's static API which works pre-init for direct sends.
      debugPrint('$_logTag: init FAILED — $e\n$st');
    }
  }

  /// Reports an exception. Drops in debug; in release with init failures
  /// falls back to a direct `Sentry.captureException` attempt, which is
  /// also a no-op if SDK state is broken but at least tries.
  static Future<void> report(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) async {
    if (kDebugMode) {
      debugPrint('$_logTag: $error\n$stackTrace');
      return;
    }
    try {
      await Sentry.captureException(error, stackTrace: stackTrace);
    } catch (_) {
      // Last-resort: print so device logs at least retain the trace.
      debugPrint('$_logTag (uninitialized): $error\n$stackTrace');
    }
  }

  /// Wraps app startup to catch uncaught exceptions inside its zone.
  static Future<void> guard(Future<void> Function() appRunner) async {
    await runZonedGuarded(
      appRunner,
      (error, stack) => report(error, stack, context: 'uncaught'),
    );
  }
}
