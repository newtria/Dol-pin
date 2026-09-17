import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';

final profilePreferencesControllerProvider =
    Provider<ProfilePreferencesController>((ref) {
      return ProfilePreferencesController(ref.watch(authRepositoryProvider));
    });

class ProfilePreferencesController {
  const ProfilePreferencesController(this._authRepository);

  final AuthRepository _authRepository;

  Future<Result<UserModel>> updateLocale({
    required String userId,
    required String locale,
  }) {
    return _authRepository.updateProfile(userId, {'locale': locale});
  }

  Future<Result<UserModel>> updateCurrency({
    required String userId,
    required String currency,
  }) {
    return _authRepository.updateProfile(userId, {'currency': currency});
  }
}
