import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';
import '../utils/mime_utils.dart';

class StorageService {
  static const _log = AppLogger('StorageService');
  static const _uuid = Uuid();

  final SupabaseClient _client;
  StorageService(this._client);

  /// Upload image to a Supabase storage bucket
  Future<String> uploadImage({
    required String bucket,
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) async {
    try {
      final fileName = '$userId/${_uuid.v4()}.$extension';
      await _client.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(
              contentType: mimeTypeForExtension(extension),
            ),
          );
      return fileName;
    } catch (e, st) {
      _log.error('uploadImage failed for bucket=$bucket', e, st);
      rethrow;
    }
  }

  /// Get a signed URL for a private bucket image
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(path, expiresIn);
    } catch (e, st) {
      _log.error('getSignedUrl failed for bucket=$bucket path=$path', e, st);
      rethrow;
    }
  }

  /// Get a public URL for a public bucket image
  String getPublicUrl({required String bucket, required String path}) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(supabaseClientProvider)),
);
