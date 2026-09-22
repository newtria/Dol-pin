import 'dart:convert';

import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/datasources/gemini_edge_client.dart';
import 'package:dolpin/data/datasources/gemini_image_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiEdgeClient', () {
    test('posts payload and prompt with auth headers', () async {
      late http.Request captured;
      final client = GeminiEdgeClient(
        functionUrl: 'https://example.supabase.co/functions/v1/gemini-analyze',
        supabaseAnonKey: 'anon-key',
        accessToken: 'jwt-1',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'result': 'Lightstick'}), 200);
        }),
      );

      final result = await client.analyze(
        payload: const GeminiImagePayload(
          image: 'base64-image',
          mimeType: 'image/jpeg',
        ),
        prompt: 'prompt',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, 'Lightstick');
      expect(captured.headers['apikey'], 'anon-key');
      expect(captured.headers['Authorization'], 'Bearer jwt-1');
      expect(jsonDecode(captured.body), {
        'image': 'base64-image',
        'mimeType': 'image/jpeg',
        'prompt': 'prompt',
      });
    });

    test('maps non-200 responses to server failures', () async {
      final client = GeminiEdgeClient(
        functionUrl: 'https://example.supabase.co/functions/v1/gemini-analyze',
        supabaseAnonKey: 'anon-key',
        httpClient: MockClient((_) async => http.Response('{}', 503)),
      );

      final result = await client.analyze(
        payload: const GeminiImagePayload(image: 'a', mimeType: 'image/jpeg'),
        prompt: 'prompt',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'Gemini analysis failed (503)');
    });

    test('rejects empty result bodies', () async {
      final client = GeminiEdgeClient(
        functionUrl: 'https://example.supabase.co/functions/v1/gemini-analyze',
        supabaseAnonKey: 'anon-key',
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'result': ''}), 200),
        ),
      );

      final result = await client.analyze(
        payload: const GeminiImagePayload(image: 'a', mimeType: 'image/jpeg'),
        prompt: 'prompt',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'No analysis result returned');
    });

    test('maps slow requests to network timeout failures', () async {
      final client = GeminiEdgeClient(
        functionUrl: 'https://example.supabase.co/functions/v1/gemini-analyze',
        supabaseAnonKey: 'anon-key',
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(jsonEncode({'result': 'late'}), 200);
        }),
      );

      final result = await client.analyze(
        payload: const GeminiImagePayload(image: 'a', mimeType: 'image/jpeg'),
        prompt: 'prompt',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
      expect(result.failure.message, 'Gemini request timed out');
    });
  });
}
