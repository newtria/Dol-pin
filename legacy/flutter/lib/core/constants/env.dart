import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL')
  static const String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY')
  static const String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(varName: 'PORTONE_IMP_CODE', defaultValue: 'imp00000000')
  static const String portOneImpCode = _Env.portOneImpCode;

  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static List<String> missingReleaseValues({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String portOneImpCode,
    required String sentryDsn,
  }) {
    final missing = <String>[];
    if (_isBlankOrPlaceholder(supabaseUrl, 'placeholder.supabase.co')) {
      missing.add('SUPABASE_URL');
    }
    if (_isBlankOrPlaceholder(supabaseAnonKey, 'placeholder-anon-key')) {
      missing.add('SUPABASE_ANON_KEY');
    }
    if (_isBlankOrPlaceholder(portOneImpCode, 'imp00000000')) {
      missing.add('PORTONE_IMP_CODE');
    }
    if (sentryDsn.trim().isEmpty) {
      missing.add('SENTRY_DSN');
    }
    return missing;
  }

  static void validateForRelease({required bool isRelease}) {
    if (!isRelease) return;

    final missing = missingReleaseValues(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      portOneImpCode: portOneImpCode,
      sentryDsn: sentryDsn,
    );
    if (missing.isNotEmpty) {
      throw StateError(
        'Release environment is incomplete: ${missing.join(', ')}',
      );
    }
  }

  static bool _isBlankOrPlaceholder(String value, String placeholder) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized.contains(placeholder);
  }
}
