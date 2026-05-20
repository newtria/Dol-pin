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

  /// Sentry DSN. Empty string disables crash reporting (e.g. in debug builds
  /// or when developers run without a Sentry project). The crash reporter
  /// short-circuits init() if this is blank.
  @EnviedField(varName: 'SENTRY_DSN', defaultValue: '')
  static const String sentryDsn = _Env.sentryDsn;
}
