import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gemini-analyze edge function contract', () {
    late String functionSource;
    late String authSource;
    late String serviceSource;
    late String edgeClientSource;

    setUpAll(() {
      functionSource = File(
        'supabase/functions/gemini-analyze/index.ts',
      ).readAsStringSync();
      authSource = File(
        'supabase/functions/_shared/auth.ts',
      ).readAsStringSync();
      serviceSource = File(
        'lib/data/datasources/gemini_service.dart',
      ).readAsStringSync();
      edgeClientSource = File(
        'lib/data/datasources/gemini_edge_client.dart',
      ).readAsStringSync();
    });

    test('requires a Supabase bearer token before calling Gemini', () {
      expect(functionSource, contains('requireAuthenticatedUser'));
      expect(authSource, contains('Missing bearer token'));
      expect(authSource, contains('auth.getUser'));
      expect(authSource, contains('Invalid token'));
      expect(
        functionSource.indexOf('requireAuthenticatedUser'),
        lessThan(functionSource.indexOf('geminiResponse = await fetch')),
      );
    });

    test('bounds Gemini request cost and latency before provider call', () {
      expect(functionSource, contains('MAX_IMAGE_BASE64_BYTES'));
      expect(functionSource, contains('MAX_PROMPT_CHARS'));
      expect(functionSource, contains('ALLOWED_MIME_TYPES'));
      expect(functionSource, contains('AbortController'));
      expect(functionSource, contains('GEMINI_TIMEOUT_MS'));
      expect(
        functionSource.indexOf('MAX_IMAGE_BASE64_BYTES'),
        lessThan(functionSource.indexOf('geminiResponse = await fetch')),
      );
      expect(
        functionSource.indexOf('ALLOWED_MIME_TYPES'),
        lessThan(functionSource.indexOf('geminiResponse = await fetch')),
      );
    });

    test('client sends the current session token when available', () {
      expect(serviceSource, contains('accessToken'));
      expect(
        edgeClientSource,
        contains("headers['Authorization'] = 'Bearer \$_accessToken'"),
      );
    });
  });
}
