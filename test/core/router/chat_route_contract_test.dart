import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat route contract', () {
    late String router;
    late String chatList;
    late String reservationScreen;
    late String reservationDetail;

    setUpAll(() {
      router = File('lib/core/router/app_router.dart').readAsStringSync();
      chatList = File(
        'lib/features/chat/screens/chat_list_screen.dart',
      ).readAsStringSync();
      reservationScreen = File(
        'lib/features/reservation/screens/reservation_screen.dart',
      ).readAsStringSync();
      reservationDetail = File(
        'lib/features/reservation/screens/reservation_detail_screen.dart',
      ).readAsStringSync();
    });

    test('makes roomId a required path parameter', () {
      expect(router, contains("path: '/chat/:roomId/:userId'"));
      expect(router, contains("roomId: state.pathParameters['roomId']!"));
      expect(router, isNot(contains("queryParameters['roomId'] ?? ''")));
    });

    test('all first-party navigations provide roomId in the path', () {
      for (final source in [chatList, reservationScreen, reservationDetail]) {
        expect(source, contains("'roomId':"));
        expect(source, isNot(contains("'roomId': roomId}")));
      }
      expect(
        reservationScreen,
        contains('chatWillBeAvailableAfterConfirmation'),
      );
      expect(reservationScreen, contains("'reservationDetail'"));
    });

    test('reservation detail does not open chat for pending holds', () {
      expect(reservationDetail, contains('canOpenChat'));
      expect(
        reservationDetail,
        contains('_isBusy || userId == null || !canOpenChat'),
      );
    });

    test(
      'keeps signup reachable for authenticated users without a profile',
      () {
        expect(router, contains('Future<bool?> _profileExists'));
        expect(router, contains('final isSignup = path == _signupPath'));
        expect(
          router,
          contains(
            'if (hasProfile == false) return isSignup ? null : _signupPath',
          ),
        );
        expect(
          router,
          contains("if (hasProfile == true && isSignup) return '/'"),
        );
        expect(router, contains('if (isLoginOrOtp) return \'/\''));
      },
    );
  });
}
