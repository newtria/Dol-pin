import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gemini-analyze edge function contract', () {
    late String functionSource;
    late String serviceSource;

    setUpAll(() {
      functionSource = File(
        'supabase/functions/gemini-analyze/index.ts',
      ).readAsStringSync();
      serviceSource = File(
        'lib/data/datasources/gemini_service.dart',
      ).readAsStringSync();
    });

    test('requires a Supabase bearer token before calling Gemini', () {
      expect(functionSource, contains('Missing bearer token'));
      expect(functionSource, contains('supabase.auth.getUser'));
      expect(functionSource, contains('Invalid token'));
      expect(
        functionSource.indexOf('supabase.auth.getUser'),
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
      expect(
        serviceSource,
        contains("headers['Authorization'] = 'Bearer \$_accessToken'"),
      );
    });
  });
}
