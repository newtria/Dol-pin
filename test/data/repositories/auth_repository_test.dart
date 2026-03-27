import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/core/errors/result.dart';
import 'package:dolpin/data/repositories/auth_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<Map<String, dynamic>> {}

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
      when(() => mockAuth.signInWithOtp(phone: '+821012345678'))
          .thenAnswer((_) async => AuthResponse());

      final result = await repository.signInWithOtp('+821012345678');
      expect(result.isSuccess, isTrue);
    });

    test('returns Fail with AuthFailure on AuthException', () async {
      when(() => mockAuth.signInWithOtp(phone: '+821012345678'))
          .thenThrow(AuthException('Rate limit exceeded'));

      final result = await repository.signInWithOtp('+821012345678');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
      expect(result.failure.message, 'Rate limit exceeded');
    });
  });

  group('verifyOtp', () {
    test('returns Success with AuthResponse on valid token', () async {
      final authResponse = AuthResponse();
      when(() => mockAuth.verifyOTP(
            phone: '+821012345678',
            token: '123456',
            type: OtpType.sms,
          )).thenAnswer((_) async => authResponse);

      final result = await repository.verifyOtp('+821012345678', '123456');
      expect(result.isSuccess, isTrue);
      expect(result.value, authResponse);
    });

    test('returns Fail on invalid token', () async {
      when(() => mockAuth.verifyOTP(
            phone: '+821012345678',
            token: '000000',
            type: OtpType.sms,
          )).thenThrow(AuthException('Invalid OTP'));

      final result = await repository.verifyOtp('+821012345678', '000000');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });
  });

  group('signOut', () {
    test('calls auth signOut', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await repository.signOut();
      verify(() => mockAuth.signOut()).called(1);
    });
  });

  group('getProfile', () {
    late MockSupabaseQueryBuilder mockQueryBuilder;
    late MockPostgrestFilterBuilder mockFilterBuilder;

    setUp(() {
      mockQueryBuilder = MockSupabaseQueryBuilder();
      mockFilterBuilder = MockPostgrestFilterBuilder();
      when(() => mockClient.from('users')).thenReturn(mockQueryBuilder);
    });

    test('returns Success(null) when user not found', () async {
      when(() => mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.eq('id', 'user-123'))
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.maybeSingle())
          .thenAnswer((_) async => null);

      final result = await repository.getProfile('user-123');
      expect(result.isSuccess, isTrue);
      expect(result.value, isNull);
    });

    test('returns Fail on PostgrestException', () async {
      when(() => mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.eq('id', 'user-123'))
          .thenThrow(PostgrestException(message: 'DB error', code: '500'));

      final result = await repository.getProfile('user-123');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });
}
