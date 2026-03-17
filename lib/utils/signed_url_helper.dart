import '../services/storage_service.dart';
import 'logger.dart';

/// Extracts a storage file path from various Supabase URL formats.
/// If the input is already a path (no http), returns it as-is.
String extractStoragePath(String urlOrPath, String bucket) {
  if (!urlOrPath.startsWith('http')) return urlOrPath;

  // Legacy public URL: /storage/v1/object/public/<bucket>/<path>
  final publicRegex = RegExp('/storage/v1/object/public/$bucket/(.+)');
  final publicMatch = publicRegex.firstMatch(urlOrPath);
  if (publicMatch != null) return publicMatch.group(1)!;

  // Signed URL: /storage/v1/object/sign/<bucket>/<path>?token=...
  final signedRegex = RegExp('/storage/v1/object/sign/$bucket/(.+?)\\?');
  final signedMatch = signedRegex.firstMatch(urlOrPath);
  if (signedMatch != null) return signedMatch.group(1)!;

  // Other storage URL format
  final otherRegex = RegExp('/storage/v1/object/[^/]+/$bucket/(.+)');
  final otherMatch = otherRegex.firstMatch(urlOrPath);
  if (otherMatch != null) return otherMatch.group(1)!;

  return urlOrPath;
}

/// Resolves a meal image URL/path to a signed URL.
/// Falls back to the original URL on failure.
Future<String?> resolveSignedMealImageUrl(String? urlOrPath) async {
  if (urlOrPath == null || urlOrPath.isEmpty) return null;

  // Already a signed URL
  if (urlOrPath.contains('token=')) return urlOrPath;

  try {
    final path = extractStoragePath(urlOrPath, 'meal-images');
    return await StorageService.getSignedUrl(bucket: 'meal-images', path: path);
  } catch (e) {
    const AppLogger('SignedUrlHelper').error('failed to resolve URL', e);
    return urlOrPath;
  }
}
