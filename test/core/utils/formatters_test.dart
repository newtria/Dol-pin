import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/core/utils/formatters.dart';
import 'package:dolpin/l10n/app_localizations_en.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats KRW correctly', () {
      expect(CurrencyFormatter.format(15000, 'KRW'), '₩15,000');
    });

    test('formats IDR correctly', () {
      expect(CurrencyFormatter.format(50000, 'IDR'), 'Rp50.000');
    });

    test('formats JPY correctly', () {
      expect(CurrencyFormatter.format(3000, 'JPY'), '¥3,000');
    });

    test('formats USD correctly (cents to dollars)', () {
      expect(CurrencyFormatter.format(1599, 'USD'), '\$15.99');
    });

    test('symbol returns correct symbols', () {
      expect(CurrencyFormatter.symbol('KRW'), '₩');
      expect(CurrencyFormatter.symbol('IDR'), 'Rp');
      expect(CurrencyFormatter.symbol('JPY'), '¥');
      expect(CurrencyFormatter.symbol('USD'), '\$');
      expect(CurrencyFormatter.symbol('EUR'), 'EUR');
    });
  });

  group('DateFormatter', () {
    final l = AppLocalizationsEn();

    test('relative returns "just now" for recent dates', () {
      expect(DateFormatter.relative(DateTime.now(), l), 'just now');
    });

    test('relative returns minutes ago', () {
      final date = DateTime.now().subtract(const Duration(minutes: 5));
      expect(DateFormatter.relative(date, l), '5m ago');
    });

    test('relative returns hours ago', () {
      final date = DateTime.now().subtract(const Duration(hours: 3));
      expect(DateFormatter.relative(date, l), '3h ago');
    });

    test('relative returns days ago', () {
      final date = DateTime.now().subtract(const Duration(days: 2));
      expect(DateFormatter.relative(date, l), '2d ago');
    });

    test('rentalPeriod formats date range', () {
      final from = DateTime(2025, 3, 10);
      final to = DateTime(2025, 3, 15);
      expect(DateFormatter.rentalPeriod(from, to), '3/10 - 3/15');
    });
  });
}
