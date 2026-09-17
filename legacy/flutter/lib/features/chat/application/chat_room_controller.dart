import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/errors/result.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/report_repository.dart';

final chatRoomControllerProvider = Provider<ChatRoomController>((ref) {
  return ChatRoomController(
    chatRepository: ref.watch(chatRepositoryProvider),
    reportRepository: ref.watch(reportRepositoryProvider),
  );
});

class ChatRoomController {
  const ChatRoomController({
    required ChatRepository chatRepository,
    required ReportRepository reportRepository,
  }) : _chatRepository = chatRepository,
       _reportRepository = reportRepository;

  final ChatRepository _chatRepository;
  final ReportRepository _reportRepository;

  Future<Result<void>> sendMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (roomId.isEmpty) {
      return const Fail<void>(ValidationFailure('Chat room is missing'));
    }
    if (trimmedText.isEmpty) {
      return const Fail<void>(ValidationFailure('Message cannot be empty'));
    }

    final result = await _chatRepository.sendRoomMessage({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': trimmedText,
    }, roomId);

    return result.when(
      success: (_) => const Success<void>(null),
      failure: (failure) => Fail<void>(failure),
    );
  }

  Future<Result<void>> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? description,
  }) {
    return _reportRepository.submitReport(
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      reason: reason,
      description: description,
    );
  }

  Future<Result<void>> blockUser({
    required String blockerId,
    required String blockedId,
  }) {
    return _reportRepository.blockUser(
      blockerId: blockerId,
      blockedId: blockedId,
    );
  }
}
