/// Centralized input validators for the app.
class Validators {
  Validators._();

  static final _phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');
  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');

  /// Validates international phone number format (E.164).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return '전화번호를 입력하세요';
    if (!_phoneRegex.hasMatch(value.trim())) return '올바른 전화번호 형식이 아닙니다';
    return null;
  }

  /// Validates that amount is positive and within a reasonable range.
  static String? amount(int? value, {int max = 10000000}) {
    if (value == null || value <= 0) return '금액은 0보다 커야 합니다';
    if (value > max) return '금액이 너무 큽니다 (최대 ${max.toString()})';
    return null;
  }

  /// Validates string length within bounds.
  static String? stringLength(
    String? value, {
    required String fieldName,
    int min = 1,
    int max = 500,
  }) {
    if (value == null || value.trim().isEmpty) return '$fieldName을(를) 입력하세요';
    final trimmed = value.trim();
    if (trimmed.length < min) return '$fieldName은(는) ${min}자 이상이어야 합니다';
    if (trimmed.length > max) return '$fieldName은(는) ${max}자 이하여야 합니다';
    return null;
  }

  static String? nickname(String? value) =>
      stringLength(value, fieldName: '닉네임', min: 2, max: 30);

  static String? title(String? value) =>
      stringLength(value, fieldName: '제목', min: 2, max: 100);

  static String? description(String? value) =>
      stringLength(value, fieldName: '설명', max: 1000);

  /// Sanitizes a search query: trims, removes control characters, limits length.
  static String sanitizeSearch(String query, {int maxLength = 200}) {
    return query.trim().replaceAll(_controlChars, '').characters.take(maxLength).toString();
  }
}
