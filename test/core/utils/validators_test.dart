import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('accepts valid E.164 numbers', () {
      expect(Validators.phone('+821012345678'), isNull);
      expect(Validators.phone('+6281234567890'), isNull);
      expect(Validators.phone('+819012345678'), isNull);
    });

    test('rejects invalid formats', () {
      expect(Validators.phone('01012345678'), isNotNull);
      expect(Validators.phone('+0123'), isNotNull);
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone(null), isNotNull);
    });
  });

  group('Validators.amount', () {
    test('accepts valid amounts', () {
      expect(Validators.amount(1), isNull);
      expect(Validators.amount(10000000), isNull);
      expect(Validators.amount(50000), isNull);
    });

    test('rejects invalid amounts', () {
      expect(Validators.amount(0), isNotNull);
      expect(Validators.amount(-1), isNotNull);
      expect(Validators.amount(null), isNotNull);
      expect(Validators.amount(10000001), isNotNull);
    });
  });

  group('Validators.nickname', () {
    test('accepts valid nicknames', () {
      expect(Validators.nickname('홍길동'), isNull);
      expect(Validators.nickname('ab'), isNull);
    });

    test('rejects too short or too long', () {
      expect(Validators.nickname('a'), isNotNull);
      expect(Validators.nickname('a' * 31), isNotNull);
      expect(Validators.nickname(''), isNotNull);
    });
  });

  group('Validators.sanitizeSearch', () {
    test('trims and removes control characters', () {
      expect(Validators.sanitizeSearch('  hello\x00world  '), 'helloworld');
    });

    test('limits length', () {
      final long = 'a' * 300;
      expect(Validators.sanitizeSearch(long).length, 200);
    });
  });
}
