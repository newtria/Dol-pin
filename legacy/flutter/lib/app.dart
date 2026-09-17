import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/notification_provider.dart';

class DolpinApp extends ConsumerWidget {
  const DolpinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the notification listener alive while the app is running.
    // It auto-subscribes when the user is authenticated and disposes on logout.
    ref.watch(notificationListenerProvider);

    return MaterialApp.router(
      title: 'dol-pin',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
