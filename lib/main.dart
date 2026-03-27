import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/env.dart';
import 'core/utils/crash_reporter.dart';
import 'data/datasources/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashReporter.guard(() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // Set Flutter error handler
    FlutterError.onError = (details) {
      CrashReporter.report(
        details.exception,
        details.stack ?? StackTrace.current,
        context: 'FlutterError',
      );
    };

    runApp(
      const ProviderScope(
        child: DolpinApp(),
      ),
    );

    // Initialize local notifications after runApp so it doesn't block
    // the first frame. Permission dialogs will show after the app is visible.
    PushNotificationService.initPlugin();
  });
}
