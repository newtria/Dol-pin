import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/chat_summary_model.dart';
import '../data/repositories/chat_repository.dart';

final chatRoomMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, String>((ref, roomId) {
      return ref.watch(chatRepositoryProvider).watchRoomMessages(roomId);
    });

final chatListProvider = FutureProvider.autoDispose
    .family<List<ChatSummaryModel>, String>((ref, userId) async {
      final result = await ref
          .watch(chatRepositoryProvider)
          .getChatList(userId);
      return result.when(success: (list) => list, failure: (f) => throw f);
    });
