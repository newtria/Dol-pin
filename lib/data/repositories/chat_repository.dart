import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../datasources/supabase_client.dart';
import '../models/chat_message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseProvider));
});

class ChatRepository {
  ChatRepository(this._client);
  final SupabaseClient _client;

  Future<Result<List<Map<String, dynamic>>>> getChatList(
      String userId) async {
    try {
      final data = await _client
          .rpc(DbFunctions.getChatList, params: {'p_user_id': userId});
      return Success(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  /// Gets or creates a chat room between two users.
  Future<Result<String>> getOrCreateRoom(String userId, String otherUserId,
      {String? itemId}) async {
    try {
      final roomId =
          await _client.rpc(DbFunctions.getOrCreateRoom, params: {
        'user_a': userId,
        'user_b': otherUserId,
        'p_item_id': itemId,
      });
      return Success(roomId as String);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  /// Streams messages for a specific chat room.
  Stream<List<ChatMessageModel>> watchRoomMessages(String roomId) {
    return _client
        .from(DbTables.chatMessages)
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((data) => data.map((e) => ChatMessageModel.fromJson(e)).toList());
  }

  /// Sends a message within a specific room.
  Future<Result<ChatMessageModel>> sendRoomMessage(
      Map<String, dynamic> message, String roomId) async {
    try {
      final data = await _client
          .from(DbTables.chatMessages)
          .insert({...message, 'room_id': roomId})
          .select()
          .single();
      return Success(ChatMessageModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
