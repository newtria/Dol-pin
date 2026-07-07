import 'package:dolpin/core/constants/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env release validation', () {
    test('is a no-op outside release builds', () {
      expect(() => Env.validateForRelease(isRelease: false), returnsNormally);
    });

    test('detects placeholder and missing production values', () {
      final missing = Env.missingReleaseValues(
        supabaseUrl: 'https://placeholder.supabase.co',
        supabaseAnonKey: 'placeholder-anon-key',
        portOneImpCode: 'imp00000000',
        sentryDsn: '',
      );

      expect(
        missing,
        containsAll([
          'SUPABASE_URL',
          'SUPABASE_ANON_KEY',
          'PORTONE_IMP_CODE',
          'SENTRY_DSN',
        ]),
      );
    });

    test('accepts concrete release values', () {
      final missing = Env.missingReleaseValues(
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'public-anon-key',
        portOneImpCode: 'imp12345678',
        sentryDsn: 'https://example@sentry.invalid/1',
      );

      expect(missing, isEmpty);
    });
  });
}
