import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/chat_repository.dart';

import '../../helpers/postgrest_fakes.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;
  late ChatRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = ChatRepository(mockClient);
  });

  group('getChatList', () {
    test('returns Success with chat list data', () async {
      final mockData = [
        {
          'room_id': 'room-1',
          'partner_id': 'user-2',
          'last_message': 'Hello',
          'unread_count': 0,
        },
        {
          'room_id': 'room-2',
          'partner_id': 'user-3',
          'last_message': 'Thanks',
          'unread_count': 2,
        },
      ];
      when(
        () => mockClient.rpc('get_chat_list', params: {'p_user_id': 'user-1'}),
      ).thenAnswer((_) => FakePostgrestResponse<dynamic>(mockData));

      final result = await repository.getChatList('user-1');

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(2));
      expect(result.value[0].roomId, 'room-1');
    });

    test('returns Fail on exception', () async {
      when(
        () => mockClient.rpc('get_chat_list', params: {'p_user_id': 'user-1'}),
      ).thenThrow(PostgrestException(message: 'function error', code: '500'));

      final result = await repository.getChatList('user-1');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('getOrCreateRoom', () {
    test('returns Success with room id', () async {
      when(
        () => mockClient.rpc(
          'get_or_create_room',
          params: {
            'user_a': 'user-1',
            'user_b': 'user-2',
            'p_item_id': 'item-1',
            'p_reservation_id': null,
          },
        ),
      ).thenAnswer((_) => FakePostgrestResponse<dynamic>('room-abc'));

      final result = await repository.getOrCreateRoom(
        'user-1',
        'user-2',
        itemId: 'item-1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, 'room-abc');
    });

    test('passes null itemId when not provided', () async {
      when(
        () => mockClient.rpc(
          'get_or_create_room',
          params: {
            'user_a': 'user-1',
            'user_b': 'user-2',
            'p_item_id': null,
            'p_reservation_id': null,
          },
        ),
      ).thenAnswer((_) => FakePostgrestResponse<dynamic>('room-def'));

      final result = await repository.getOrCreateRoom('user-1', 'user-2');

      expect(result.isSuccess, isTrue);
      expect(result.value, 'room-def');
    });

    test('returns Fail on exception', () async {
      when(
        () => mockClient.rpc(
          'get_or_create_room',
          params: {
            'user_a': 'user-1',
            'user_b': 'user-2',
            'p_item_id': null,
            'p_reservation_id': null,
          },
        ),
      ).thenThrow(PostgrestException(message: 'rpc error', code: '500'));

      final result = await repository.getOrCreateRoom('user-1', 'user-2');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('sendRoomMessage', () {
    late MockSupabaseQueryBuilder mockQueryBuilder;
    late MockPostgrestFilterBuilder<PostgrestList> mockFilterBuilder;

    setUp(() {
      mockQueryBuilder = MockSupabaseQueryBuilder();
      mockFilterBuilder = MockPostgrestFilterBuilder<PostgrestList>();
      when(
        () => mockClient.from('chat_messages'),
      ).thenAnswer((_) => mockQueryBuilder);
    });

    test('returns Success with ChatMessageModel on insert', () async {
      final insertedData = {
        'id': 'msg-1',
        'room_id': 'room-1',
        'sender_id': 'user-1',
        'receiver_id': 'user-2',
        'message': 'Hi there',
        'created_at': '2026-03-28T12:00:00.000Z',
      };
      when(
        () => mockQueryBuilder.insert({
          'sender_id': 'user-1',
          'receiver_id': 'user-2',
          'message': 'Hi there',
          'room_id': 'room-1',
        }),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.select(),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.single(),
      ).thenAnswer((_) => FakePostgrestResponse<PostgrestMap>(insertedData));

      final result = await repository.sendRoomMessage({
        'sender_id': 'user-1',
        'receiver_id': 'user-2',
        'message': 'Hi there',
      }, 'room-1');

      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'msg-1');
      expect(result.value.message, 'Hi there');
    });

    test('returns Fail on insert exception', () async {
      when(
        () => mockQueryBuilder.insert({
          'sender_id': 'user-1',
          'message': 'test',
          'room_id': 'room-1',
        }),
      ).thenThrow(PostgrestException(message: 'insert failed', code: '500'));

      final result = await repository.sendRoomMessage({
        'sender_id': 'user-1',
        'message': 'test',
      }, 'room-1');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

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
