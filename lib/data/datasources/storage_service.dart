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
    final ext = file.path.split('.').last;
    final path = 'items/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    return _uploadPublic(
      bucket: StorageBuckets.rentalPhotos,
      path: path,
      file: file,
    );
  }

  Future<Result<String>> uploadReturnPhoto({
    required String userId,
    required String reservationId,
    required File file,
  }) async {
    final ext = file.path.split('.').last;
    final path =
        'returns/$reservationId/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    return _uploadPublic(
      bucket: StorageBuckets.rentalPhotos,
      path: path,
      file: file,
    );
  }

  Future<Result<String>> uploadProfilePhoto(String userId, File file) async {
    final ext = file.path.split('.').last;
    final path = 'profiles/$userId.$ext';
    return _uploadPublic(
      bucket: StorageBuckets.profilePhotos,
      path: path,
      file: file,
      fileOptions: const FileOptions(upsert: true),
    );
  }

  Future<Result<String>> uploadChatImage(String chatId, File file) async {
    final ext = file.path.split('.').last;
    final path = 'chat/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    return _uploadPublic(
      bucket: StorageBuckets.chatImages,
      path: path,
      file: file,
    );
  }

  Future<Result<String>> _uploadPublic({
    required String bucket,
    required String path,
    required File file,
    FileOptions? fileOptions,
  }) async {
    try {
      final storage = _client.storage.from(bucket);
      if (fileOptions == null) {
        await storage.upload(path, file);
      } else {
        await storage.upload(path, file, fileOptions: fileOptions);
      }
      return Success(storage.getPublicUrl(path));
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
