import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late AuthRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repository = AuthRepository(mockClient);
  });

  group('signInWithOtp', () {
    test('returns Success on successful OTP send', () async {
      when(
        () => mockAuth.signInWithOtp(phone: '+821012345678'),
      ).thenAnswer((_) async => AuthResponse());

      final result = await repository.signInWithOtp('+821012345678');

      expect(result.isSuccess, isTrue);
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => mockAuth.signInWithOtp(phone: '+821012345678'),
      ).thenThrow(AuthException('Rate limit exceeded'));

      final result = await repository.signInWithOtp('+821012345678');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
      expect(result.failure.message, 'Rate limit exceeded');
    });

    test('rate-limits repeated OTP requests before calling Supabase', () async {
      when(
        () => mockAuth.signInWithOtp(phone: '+821012345678'),
      ).thenAnswer((_) async => AuthResponse());

      await repository.signInWithOtp('+821012345678');
      final second = await repository.signInWithOtp('+821012345678');

      expect(second.isFailure, isTrue);
      expect(second.failure, isA<OtpRateLimitFailure>());
      verify(() => mockAuth.signInWithOtp(phone: '+821012345678')).called(1);
    });
  });

  group('verifyOtp', () {
    test('returns Success with AuthResponse on valid token', () async {
      final authResponse = AuthResponse();
      when(
        () => mockAuth.verifyOTP(
          phone: '+821012345678',
          token: '123456',
          type: OtpType.sms,
        ),
      ).thenAnswer((_) async => authResponse);

      final result = await repository.verifyOtp('+821012345678', '123456');

      expect(result.isSuccess, isTrue);
      expect(result.value, authResponse);
    });
  });

  test('signOut delegates to Supabase auth', () async {
    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    await repository.signOut();

    verify(() => mockAuth.signOut()).called(1);
  });
}
