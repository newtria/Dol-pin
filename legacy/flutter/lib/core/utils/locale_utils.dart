/// Shared country → currency/locale mapping.
/// Used in signup and settings.
class LocaleUtils {
  static const countryCurrencyMap = {
    'KR': 'KRW',
    'ID': 'IDR',
    'JP': 'JPY',
    'US': 'USD',
  };

  static const countryLocaleMap = {
    'KR': 'ko',
    'ID': 'id',
    'JP': 'ja',
    'US': 'en',
  };

  static String currencyForCountry(String countryCode) =>
      countryCurrencyMap[countryCode] ?? 'USD';

  static String localeForCountry(String countryCode) =>
      countryLocaleMap[countryCode] ?? 'en';
}
