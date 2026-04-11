import 'package:characters/characters.dart';

/// Centralized input validators for the app.
///
/// Messages are intentionally English so they render sensibly in the
/// EN/JA/ID locales. The Korean locale will see English fallback until we
/// migrate validators to consume [AppLocalizations] at the call site.
class Validators {
  Validators._();

  static final _phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');
  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');

  /// Validates international phone number format (E.164).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!_phoneRegex.hasMatch(value.trim())) {
      return 'Invalid phone number format';
    }
    return null;
  }

  /// Validates that amount is positive and within a reasonable range.
  static String? amount(int? value, {int max = 10000000}) {
    if (value == null || value <= 0) return 'Amount must be greater than 0';
    if (value > max) return 'Amount is too large (max ${max.toString()})';
    return null;
  }

  /// Validates string length within bounds.
  static String? stringLength(
    String? value, {
    required String fieldName,
    int min = 1,
    int max = 500,
  }) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    final trimmed = value.trim();
    if (trimmed.length < min) {
      return '$fieldName must be at least $min characters';
    }
    if (trimmed.length > max) {
      return '$fieldName must be at most $max characters';
    }
    return null;
  }

  static String? nickname(String? value) =>
      stringLength(value, fieldName: 'Nickname', min: 2, max: 30);

  static String? title(String? value) =>
      stringLength(value, fieldName: 'Title', min: 2, max: 100);

  static String? description(String? value) =>
      stringLength(value, fieldName: 'Description', max: 1000);

  /// Sanitizes a search query: trims, removes control characters, limits length.
  static String sanitizeSearch(String query, {int maxLength = 200}) {
    return query.trim().replaceAll(_controlChars, '').characters.take(maxLength).toString();
  }
}
