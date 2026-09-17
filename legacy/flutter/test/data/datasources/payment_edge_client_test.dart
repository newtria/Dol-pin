import 'dart:convert';

import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/datasources/payment_edge_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PaymentEdgeClient', () {
    test('posts JSON with Supabase auth headers', () async {
      late http.Request captured;
      final client = PaymentEdgeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      final result = await client.postJson(
        functionName: 'verify-payment',
        authJwt: 'jwt-1',
        body: {'imp_uid': 'imp-1'},
        timeoutMessage: 'timeout',
        failureMessage: 'failed',
      );

      expect(result.isSuccess, isTrue);
      expect(captured.url.path, endsWith('/functions/v1/verify-payment'));
      expect(captured.headers['Authorization'], 'Bearer jwt-1');
      expect(captured.headers['Content-Type'], 'application/json');
      expect(jsonDecode(captured.body), {'imp_uid': 'imp-1'});
    });

    test('does not hit the network without an auth token', () async {
      var called = false;
      final client = PaymentEdgeClient(
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      final result = await client.postJson(
        functionName: 'verify-payment',
        authJwt: '',
        body: const {},
        timeoutMessage: 'timeout',
        failureMessage: 'failed',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<PaymentFailure>());
      expect(result.failure.message, 'Authentication required');
      expect(called, isFalse);
    });

    test('uses edge error body and imp_uid for non-200 responses', () async {
      final client = PaymentEdgeClient(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({'error': 'provider failed', 'imp_uid': 'imp-1'}),
            502,
          );
        }),
      );

      final result = await client.postJson(
        functionName: 'refund-payment',
        authJwt: 'jwt-1',
        body: const {},
        timeoutMessage: 'timeout',
        failureMessage: 'Refund failed',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'provider failed (imp_uid: imp-1)');
    });

    test('returns timeout failure when the edge function hangs', () async {
      final client = PaymentEdgeClient(
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
      );

      final result = await client.postJson(
        functionName: 'settle-reservation',
        authJwt: 'jwt-1',
        body: const {},
        timeoutMessage: 'Settlement request timed out',
        failureMessage: 'Settlement failed',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'Settlement request timed out');
    });
  });

  group('edgeErrorMessage', () {
    test('falls back for malformed response bodies', () {
      final message = edgeErrorMessage(
        http.Response('not json', 500),
        'Fallback',
      );

      expect(message, 'Fallback');
    });
  });
}
