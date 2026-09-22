import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/core/errors/result.dart';
import 'package:dolpin/data/models/chat_message_model.dart';
import 'package:dolpin/data/repositories/chat_repository.dart';
import 'package:dolpin/data/repositories/report_repository.dart';
import 'package:dolpin/features/chat/application/chat_room_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ChatRoomController', () {
    late _FakeChatRepository chatRepository;
    late _FakeReportRepository reportRepository;
    late ChatRoomController controller;

    setUp(() {
      chatRepository = _FakeChatRepository();
      reportRepository = _FakeReportRepository();
      controller = ChatRoomController(
        chatRepository: chatRepository,
        reportRepository: reportRepository,
      );
    });

    test('trims and sends messages through the room repository', () async {
      final result = await controller.sendMessage(
        roomId: 'room-1',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        text: '  hello  ',
      );

      expect(result.isSuccess, isTrue);
      expect(chatRepository.sentRoomId, 'room-1');
      expect(chatRepository.sentMessage, {
        'sender_id': 'sender-1',
        'receiver_id': 'receiver-1',
        'message': 'hello',
      });
    });

    test('rejects blank messages before hitting the repository', () async {
      final result = await controller.sendMessage(
        roomId: 'room-1',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        text: '   ',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
      expect(chatRepository.sendCalls, 0);
    });

    test('passes through send failures', () async {
      chatRepository.nextSendResult = const Fail(
        ServerFailure('insert failed'),
      );

      final result = await controller.sendMessage(
        roomId: 'room-1',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        text: 'hello',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'insert failed');
    });

    test('delegates report and block actions', () async {
      final reportResult = await controller.reportUser(
        reporterId: 'reporter-1',
        reportedUserId: 'reported-1',
        reason: 'spam',
        description: 'too much',
      );
      final blockResult = await controller.blockUser(
        blockerId: 'blocker-1',
        blockedId: 'blocked-1',
      );

      expect(reportResult.isSuccess, isTrue);
      expect(blockResult.isSuccess, isTrue);
      expect(reportRepository.reportPayload, {
        'reporterId': 'reporter-1',
        'reportedUserId': 'reported-1',
        'reason': 'spam',
        'description': 'too much',
      });
      expect(reportRepository.blockPayload, {
        'blockerId': 'blocker-1',
        'blockedId': 'blocked-1',
      });
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(MockSupabaseClient());

  int sendCalls = 0;
  String? sentRoomId;
  Map<String, dynamic>? sentMessage;
  Result<ChatMessageModel> nextSendResult = Success(
    ChatMessageModel(
      id: 'message-1',
      senderId: 'sender-1',
      receiverId: 'receiver-1',
      message: 'hello',
      createdAt: DateTime(2026),
    ),
  );

  @override
  Future<Result<ChatMessageModel>> sendRoomMessage(
    Map<String, dynamic> message,
    String roomId,
  ) async {
    sendCalls += 1;
    sentRoomId = roomId;
    sentMessage = message;
    return nextSendResult;
  }
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository() : super(MockSupabaseClient());

  Map<String, dynamic>? reportPayload;
  Map<String, dynamic>? blockPayload;

  @override
  Future<Result<void>> submitReport({
    required String reporterId,
    String? reportedUserId,
    String? reportedItemId,
    required String reason,
    String? description,
  }) async {
    reportPayload = {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reportedItemId': reportedItemId,
      'reason': reason,
      'description': description,
    }..removeWhere((_, value) => value == null);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    blockPayload = {'blockerId': blockerId, 'blockedId': blockedId};
    return const Success<void>(null);
  }
}
