import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/env.dart';
import 'core/utils/crash_reporter.dart';
import 'data/datasources/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashReporter.guard(() async {
    // Sentry's error hooks install synchronously inside SentryFlutter.init
    // before the returned future completes, so running it concurrently with
    // Supabase.initialize is safe and shaves one round-trip off cold start.
    await Future.wait([
      CrashReporter.init(Env.sentryDsn),
      Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      ),
    ]);

    // Flutter framework errors (widget lifecycle, rendering, etc.)
    FlutterError.onError = (details) {
      CrashReporter.report(
        details.exception,
        details.stack ?? StackTrace.current,
        context: 'FlutterError',
      );
    };

    // Async errors that escape widgets (e.g. unawaited Futures that throw).
    // Flutter 3.3+ surfaces these via PlatformDispatcher.instance.onError
    // rather than the zone; both handlers are needed for full coverage.
    PlatformDispatcher.instance.onError = (error, stack) {
      CrashReporter.report(error, stack, context: 'PlatformDispatcher');
      return true;
    };

    // Replace the default red error screen with a friendly fallback on
    // release. In debug, keep the red screen so we can see the exception.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      CrashReporter.report(
        details.exception,
        details.stack ?? StackTrace.current,
        context: 'ErrorWidget',
      );
      if (!kReleaseMode) {
        return ErrorWidget.withDetails(
          message: details.exceptionAsString(),
        );
      }
      return const _ReleaseErrorFallback();
    };

    runApp(
      const ProviderScope(
        child: DolpinApp(),
      ),
    );

    // Initialize local notifications after runApp so it doesn't block
    // the first frame. Permission dialogs will show after the app is
    // visible. Intentionally unawaited — we do not want to delay the UI
    // on the plugin handshake.
    unawaited(PushNotificationService.initPlugin());
  });
}

/// Minimal, crash-safe widget shown in place of the red error screen on
/// release builds. Intentionally uses raw Material widgets and no localized
/// strings so it is guaranteed to render even when the app's theme/l10n
/// subsystem is what's broken.
class _ReleaseErrorFallback extends StatelessWidget {
  const _ReleaseErrorFallback();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                'Something went wrong.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Please restart the app. If the problem persists, contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
