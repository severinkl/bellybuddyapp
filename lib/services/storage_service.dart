import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../utils/mime_utils.dart';
import 'supabase_service.dart';

class StorageService {
  static const _uuid = Uuid();

  /// Upload image to a Supabase storage bucket
  static Future<String> uploadImage({
    required String bucket,
    required String userId,
    required Uint8List fileBytes,
    required String extension,
  }) async {
    final fileName = '$userId/${_uuid.v4()}.$extension';
    await SupabaseService.storage.from(bucket).uploadBinary(
      fileName,
      fileBytes,
      fileOptions: FileOptions(contentType: mimeTypeForExtension(extension)),
    );
    return fileName;
  }

  /// Get a signed URL for a private bucket image
  static Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    return await SupabaseService.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
  }

  /// Get a public URL for a public bucket image
  static String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return SupabaseService.storage.from(bucket).getPublicUrl(path);
  }
}
