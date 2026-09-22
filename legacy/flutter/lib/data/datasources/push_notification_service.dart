import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/database.dart';
import '../datasources/supabase_client.dart';

// NOTE: firebase_core and firebase_messaging need to be added via FlutterFire CLI.
// Run `flutterfire configure` to generate firebase_options.dart and register
// platform-specific settings. Then add the following to pubspec.yaml:
//   firebase_core: ^3.x.x
//   firebase_messaging: ^15.x.x
// Actual Firebase initialization and message handling requires those packages
// and platform-specific setup (GoogleService-Info.plist / google-services.json).

/// Notification channel IDs for Android.
class NotificationChannels {
  static const reservationChannelId = 'dolpin_reservations';
  static const reservationChannelName = 'Reservations';
  static const reservationChannelDesc =
      'Notifications for new reservation requests';

  static const chatChannelId = 'dolpin_chat';
  static const chatChannelName = 'Chat Messages';
  static const chatChannelDesc = 'Notifications for new chat messages';
}

/// Shared plugin instance — the platform channel is process-global,
/// so a single instance is reused across all callers.
final _plugin = FlutterLocalNotificationsPlugin();

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(ref.watch(supabaseProvider));
});

class PushNotificationService {
  PushNotificationService(this._client);
  final SupabaseClient _client;

  int _nextNotificationId = 0;

  /// One-time plugin initialization. Called from main() after runApp().
  /// Safe to call multiple times (subsequent calls are no-ops at the
  /// platform channel level).
  static Future<void> initPlugin() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels.
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await Future.wait([
          androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              NotificationChannels.reservationChannelId,
              NotificationChannels.reservationChannelName,
              description: NotificationChannels.reservationChannelDesc,
              importance: Importance.high,
            ),
          ),
          androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              NotificationChannels.chatChannelId,
              NotificationChannels.chatChannelName,
              description: NotificationChannels.chatChannelDesc,
              importance: Importance.defaultImportance,
            ),
          ),
        ]);
      }
    }

    // Request notification permission on iOS/macOS.
    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Request notification permission on Android 13+.
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  /// Shows a local notification with a [title], [body], and optional [payload].
  ///
  /// Use [channelId] to target a specific Android notification channel.
  /// Defaults to the reservations channel.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = NotificationChannels.reservationChannelId,
    String channelName = NotificationChannels.reservationChannelName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      _nextNotificationId++,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Convenience: show a reservation notification.
  Future<void> showReservationNotification({
    required String title,
    required String body,
    String? reservationId,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: reservationId != null ? 'reservation:$reservationId' : null,
      channelId: NotificationChannels.reservationChannelId,
      channelName: NotificationChannels.reservationChannelName,
    );
  }

  /// Convenience: show a chat message notification.
  Future<void> showChatNotification({
    required String title,
    required String body,
    String? roomId,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: roomId != null ? 'chat:$roomId' : null,
      channelId: NotificationChannels.chatChannelId,
      channelName: NotificationChannels.chatChannelName,
    );
  }

  /// Stores FCM token in user's profile for server-side push.
  Future<void> registerToken(String userId, String fcmToken) async {
    await _client
        .from(DbTables.users)
        .update({'fcm_token': fcmToken})
        .eq('id', userId);
  }

  /// Removes FCM token on sign out.
  Future<void> unregisterToken(String userId) async {
    await _client
        .from(DbTables.users)
        .update({'fcm_token': null})
        .eq('id', userId);
  }

  /// Callback when user taps a notification.
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    // Navigation based on payload will be wired up with the router later.
    debugPrint('Notification tapped with payload: $payload');
  }
}
