import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat room SQL contract', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/011_chat_rooms.sql',
      ).readAsStringSync();
    });

    test('drops old get_chat_list before changing returned columns', () {
      expect(
        migration,
        contains('DROP FUNCTION IF EXISTS get_chat_list(UUID);'),
      );
      expect(migration, contains('room_id UUID'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION get_chat_list'));
    });

    test('supports reservation-scoped rooms', () {
      expect(
        migration,
        contains('reservation_id UUID REFERENCES reservations(id)'),
      );
      expect(migration, contains('p_reservation_id UUID DEFAULT NULL'));
      expect(migration, contains('idx_chat_rooms_reservation'));
    });

    test('does not allow clients to insert arbitrary rooms directly', () {
      expect(migration, contains('CREATE POLICY "Users can create rooms"'));
      expect(migration, contains('FOR INSERT WITH CHECK (false)'));
      expect(
        migration,
        contains(
          'GRANT EXECUTE ON FUNCTION get_or_create_room(UUID, UUID, UUID, UUID)',
        ),
      );
    });

    test('validates caller, reservation, and item participants inside RPC', () {
      expect(migration, contains("v_uid := auth.uid();"));
      expect(migration, contains("current_setting('role', true)"));
      expect(migration, contains('not authorized to create this room'));
      expect(migration, contains('cannot create a room with yourself'));
      expect(migration, contains('reservation participants mismatch'));
      expect(migration, contains('item lender must participate in the room'));
      expect(migration, contains("v_item.status <> 'active'"));
    });

    test('security-definer chat functions pin their search path', () {
      expect(
        migration,
        contains(
          'LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp',
        ),
      );
    });

    test('message policies are room-membership aware', () {
      expect(migration, contains('chat_messages.room_id'));
      expect(migration, contains('chat_messages.receiver_id'));
      expect(migration, contains('room_id IS NOT NULL'));
      expect(
        migration,
        contains(
          'cr.participant_1 = auth.uid() OR cr.participant_2 = auth.uid()',
        ),
      );
    });

    test('message content is immutable except read metadata', () {
      expect(
        migration,
        contains(
          'CREATE OR REPLACE FUNCTION chat_messages_block_immutable_update',
        ),
      );
      expect(migration, contains('NEW.message IS DISTINCT FROM OLD.message'));
      expect(migration, contains('NEW.location IS DISTINCT FROM OLD.location'));
    });

    test('rooms keep last-message metadata in sync', () {
      expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION update_chat_room_last_message'),
      );
      expect(migration, contains('last_message = COALESCE(NEW.message'));
      expect(migration, contains('AFTER INSERT ON chat_messages'));
    });
  });
}
