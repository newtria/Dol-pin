import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';

import '../datasources/supabase_client.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  DateTime? _lastOtpRequest;
  static const _otpCooldown = Duration(seconds: 60);

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<Result<void>> signInWithOtp(String phone) async {
    final now = DateTime.now();
    if (_lastOtpRequest != null &&
        now.difference(_lastOtpRequest!) < _otpCooldown) {
      return Fail(const ValidationFailure('잠시 후 다시 시도해주세요 (60초 제한)'));
    }
    try {
      await _client.auth.signInWithOtp(phone: phone);
      _lastOtpRequest = now;
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<AuthResponse>> verifyOtp(String phone, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return Success(response);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<bool>> signInWithApple() async {
    try {
      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: AppConstants.oauthCallbackUrl,
      );
      return Success(result);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<bool>> signInWithGoogle() async {
    try {
      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConstants.oauthCallbackUrl,
      );
      return Success(result);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Result<UserModel?>> getProfile(String userId) async {
    try {
      final data = await _client
          .from(DbTables.users)
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return const Success(null);
      return Success(UserModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<UserModel>> createProfile(
      Map<String, dynamic> profile) async {
    try {
      final data = await _client
          .from(DbTables.users)
          .insert(profile)
          .select()
          .single();
      return Success(UserModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<UserModel>> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      final data = await _client
          .from(DbTables.users)
          .update(updates)
          .eq('id', userId)
          .select()
          .single();
      return Success(UserModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<void>> softDelete(String userId) async {
    try {
      await _client.from(DbTables.users).update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      await _client.auth.signOut();
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
