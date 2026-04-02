import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_message_model.dart';
import '../data/repositories/chat_repository.dart';

final chatRoomMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).watchRoomMessages(roomId);
});

final chatListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final result = await ref.watch(chatRepositoryProvider).getChatList(userId);
  return result.when(
    success: (list) => list,
    failure: (f) => throw Exception('${f.runtimeType}: ${f.message}'),
  );
});
