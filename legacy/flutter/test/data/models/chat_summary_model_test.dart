import 'package:dolpin/data/models/chat_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatSummaryModel', () {
    test('parses get_chat_list RPC rows into typed fields', () {
      final summary = ChatSummaryModel.fromJson({
        'room_id': 'room-1',
        'partner_id': 'user-2',
        'partner_nickname': '  Mina  ',
        'partner_image': 'https://example.com/avatar.png',
        'last_message': 'See you there',
        'last_message_at': '2026-06-23T10:15:00Z',
        'unread_count': 3,
      });

      expect(summary.roomId, 'room-1');
      expect(summary.partnerId, 'user-2');
      expect(summary.partnerNickname, 'Mina');
      expect(summary.partnerImage, 'https://example.com/avatar.png');
      expect(summary.lastMessage, 'See you there');
      expect(summary.lastMessageAt, DateTime.parse('2026-06-23T10:15:00Z'));
      expect(summary.unreadCount, 3);
    });

    test('uses safe defaults for nullable presentation fields', () {
      final summary = ChatSummaryModel.fromJson({
        'room_id': 'room-1',
        'partner_id': 'user-2',
        'partner_nickname': '',
        'last_message': null,
        'unread_count': null,
      });

      expect(summary.partnerNickname, isNull);
      expect(summary.partnerImage, isNull);
      expect(summary.lastMessage, '');
      expect(summary.lastMessageAt, isNull);
      expect(summary.unreadCount, 0);
    });

    test('rejects rows without required routing fields', () {
      expect(
        () => ChatSummaryModel.fromJson({'partner_id': 'user-2'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ChatSummaryModel.fromJson({'room_id': 'room-1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
