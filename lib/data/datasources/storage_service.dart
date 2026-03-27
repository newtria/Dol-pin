import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import 'supabase_client.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseProvider));
});

class StorageService {
  StorageService(this._client);
  final SupabaseClient _client;

  Future<Result<String>> uploadItemPhoto(String userId, File file) async {
    try {
      final ext = file.path.split('.').last;
      final path =
          'items/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from(StorageBuckets.rentalPhotos).upload(path, file);
      final url =
          _client.storage.from(StorageBuckets.rentalPhotos).getPublicUrl(path);
      return Success(url);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<String>> uploadProfilePhoto(String userId, File file) async {
    try {
      final ext = file.path.split('.').last;
      final path = 'profiles/$userId.$ext';
      await _client.storage.from(StorageBuckets.profilePhotos).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      final url =
          _client.storage.from(StorageBuckets.profilePhotos).getPublicUrl(path);
      return Success(url);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<String>> uploadChatImage(String chatId, File file) async {
    try {
      final ext = file.path.split('.').last;
      final path =
          'chat/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from(StorageBuckets.chatImages).upload(path, file);
      final url =
          _client.storage.from(StorageBuckets.chatImages).getPublicUrl(path);
      return Success(url);
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
