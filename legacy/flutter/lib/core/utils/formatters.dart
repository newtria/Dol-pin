import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

class CurrencyFormatter {
  static final _formatCache = <String, NumberFormat>{};

  static NumberFormat _getFormat(String currency) {
    return _formatCache.putIfAbsent(
      currency,
      () => switch (currency) {
        'KRW' => NumberFormat('#,###', 'ko'),
        'IDR' => NumberFormat('#,###', 'id'),
        'JPY' => NumberFormat('#,###', 'ja'),
        _ => NumberFormat('#,##0.00', 'en'),
      },
    );
  }

  static String symbol(String currency) => switch (currency) {
    'KRW' => '\u20A9',
    'IDR' => 'Rp',
    'JPY' => '\u00A5',
    'USD' => '\$',
    _ => currency,
  };

  static String format(int amountMinor, String currency) {
    final fmt = _getFormat(currency);
    final sym = symbol(currency);

    // KRW, JPY, IDR are zero-decimal currencies
    final amount = switch (currency) {
      'KRW' || 'JPY' || 'IDR' => amountMinor,
      _ => amountMinor / 100,
    };

    return '$sym${fmt.format(amount)}';
  }
}

class DateFormatter {
  static String concertDate(DateTime date) {
    return DateFormat('MMM d, yyyy (E)').format(date);
  }

  static String rentalPeriod(DateTime from, DateTime to) {
    final f = DateFormat('M/d');
    return '${f.format(from)} - ${f.format(to)}';
  }

  static String relative(DateTime date, AppLocalizations l) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return l.timeJustNow;
    if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
    return DateFormat('M/d').format(date);
  }
}
