import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Provides the current user ID from auth state (no DB call).
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session?.user.id;
});

/// Fetches the full user profile from DB when authenticated.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final result = await ref.read(authRepositoryProvider).getProfile(userId);
  return result.when(
    success: (user) => user,
    failure: (_) => null,
  );
});
