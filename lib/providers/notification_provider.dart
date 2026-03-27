import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/database.dart';
import '../core/constants/enums.dart';
import '../data/datasources/push_notification_service.dart';
import '../data/datasources/supabase_client.dart';
import 'auth_provider.dart';

/// Manages Supabase Realtime subscriptions that trigger local notifications
/// for the currently authenticated user.
///
/// Watch this provider at app level (e.g. in the root widget) so that
/// subscriptions stay active while the user is logged in.
final notificationListenerProvider = Provider<NotificationListener>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(pushNotificationServiceProvider);
  final client = ref.watch(supabaseProvider);

  final listener = NotificationListener(
    userId: userId,
    service: service,
    client: client,
  );

  ref.onDispose(listener.dispose);

  if (userId != null) {
    listener.start();
  }

  return listener;
});

class NotificationListener {
  NotificationListener({
    required this.userId,
    required this.service,
    required this.client,
  });

  final String? userId;
  final PushNotificationService service;
  final SupabaseClient client;

  RealtimeChannel? _reservationChannel;
  RealtimeChannel? _chatChannel;

  /// Starts listening for new reservations and chat messages via Supabase
  /// Realtime Postgres Changes.
  void start() {
    if (userId == null) return;
    _listenForReservations();
    _listenForChatMessages();
  }

  /// Subscribes to INSERT events on the reservations table where the current
  /// user is the lender.
  void _listenForReservations() {
    _reservationChannel = client
        .channel('reservations_for_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: DbTables.reservations,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'lender_id',
            value: userId!,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final reservationId = record['id'] as String?;
            final status = record['status'] as String? ?? 'pending';

            if (status == ReservationStatus.pending.value) {
              service.showReservationNotification(
                title: 'New Reservation Request',
                body: 'Someone wants to rent your item!',
                reservationId: reservationId,
              );
            }
          },
        )
        .subscribe((status, [error]) {
      debugPrint(
        'Reservation channel status: $status${error != null ? ', error: $error' : ''}',
      );
    });
  }

  /// Subscribes to INSERT events on the chat_messages table where the current
  /// user is the receiver.
  void _listenForChatMessages() {
    _chatChannel = client
        .channel('chat_messages_for_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: DbTables.chatMessages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId!,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final message = record['message'] as String?;
            final roomId = record['room_id'] as String?;

            service.showChatNotification(
              title: 'New Message',
              body: message ?? 'You received an image',
              roomId: roomId,
            );
          },
        )
        .subscribe((status, [error]) {
      debugPrint(
        'Chat channel status: $status${error != null ? ', error: $error' : ''}',
      );
    });
  }

  /// Unsubscribes from all Realtime channels.
  void dispose() {
    _reservationChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
  }
}
