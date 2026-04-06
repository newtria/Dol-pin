import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/chat_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

/// A fake [PostgrestBuilder] that resolves to [_value] when awaited.
class FakePostgrestResponse<T> extends Fake implements PostgrestBuilder<T> {
  final T _value;
  FakePostgrestResponse(this._value);

  @override
  Future<S> then<S>(FutureOr<S> Function(T value) onValue,
          {Function? onError}) =>
      Future<T>.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future<T>.value(_value);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_value).whenComplete(action);

  @override
  Stream<T> asStream() => Stream.value(_value);

  @override
  Future<T> timeout(Duration timeLimit,
          {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_value);
}

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
        {'room_id': 'room-1', 'last_message': 'Hello'},
        {'room_id': 'room-2', 'last_message': 'Thanks'},
      ];
      when(() => mockClient.rpc('get_chat_list',
          params: {'p_user_id': 'user-1'})).thenAnswer((_) async => mockData);

      final result = await repository.getChatList('user-1');
      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(2));
      expect(result.value[0]['room_id'], 'room-1');
    });

    test('returns Fail on exception', () async {
      when(() => mockClient.rpc('get_chat_list',
              params: {'p_user_id': 'user-1'}))
          .thenThrow(PostgrestException(message: 'function error', code: '500'));

      final result = await repository.getChatList('user-1');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('getOrCreateRoom', () {
    test('returns Success with room id', () async {
      when(() => mockClient.rpc('get_or_create_room', params: {
            'user_a': 'user-1',
            'user_b': 'user-2',
            'p_item_id': 'item-1',
          })).thenAnswer((_) async => 'room-abc');

      final result = await repository.getOrCreateRoom(
        'user-1',
        'user-2',
        itemId: 'item-1',
      );
      expect(result.isSuccess, isTrue);
      expect(result.value, 'room-abc');
    });

    test('passes null itemId when not provided', () async {
      when(() => mockClient.rpc('get_or_create_room', params: {
            'user_a': 'user-1',
            'user_b': 'user-2',
            'p_item_id': null,
          })).thenAnswer((_) async => 'room-def');

      final result = await repository.getOrCreateRoom('user-1', 'user-2');
      expect(result.isSuccess, isTrue);
      expect(result.value, 'room-def');
    });

    test('returns Fail on exception', () async {
      when(() => mockClient.rpc('get_or_create_room', params: {
            'user_a': 'user-1',
            'user_b': 'user-2',
            'p_item_id': null,
          })).thenThrow(PostgrestException(message: 'rpc error', code: '500'));

      final result = await repository.getOrCreateRoom('user-1', 'user-2');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('sendRoomMessage', () {
    late MockSupabaseQueryBuilder mockQueryBuilder;
    late MockPostgrestFilterBuilder mockFilterBuilder;

    setUp(() {
      mockQueryBuilder = MockSupabaseQueryBuilder();
      mockFilterBuilder = MockPostgrestFilterBuilder();
      when(() => mockClient.from('chat_messages'))
          .thenReturn(mockQueryBuilder);
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
      when(() => mockQueryBuilder.insert({
            'sender_id': 'user-1',
            'receiver_id': 'user-2',
            'message': 'Hi there',
            'room_id': 'room-1',
          })).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select())
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single())
          .thenReturn(FakePostgrestResponse<PostgrestMap>(insertedData));

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
      when(() => mockQueryBuilder.insert({
            'sender_id': 'user-1',
            'message': 'test',
            'room_id': 'room-1',
          })).thenThrow(
          PostgrestException(message: 'insert failed', code: '500'));

      final result = await repository.sendRoomMessage({
        'sender_id': 'user-1',
        'message': 'test',
      }, 'room-1');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });
}
