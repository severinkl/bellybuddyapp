import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/signed_url_helper.dart';

void main() {
  const bucket = 'meal-images';

  group('extractStoragePath', () {
    test('non-http path returns as-is', () {
      expect(extractStoragePath('user/photo.jpg', bucket), 'user/photo.jpg');
    });

    test('legacy public URL extracts path after bucket', () {
      const url =
          'https://example.supabase.co/storage/v1/object/public/meal-images/user/photo.jpg';
      expect(extractStoragePath(url, bucket), 'user/photo.jpg');
    });

    test('signed URL extracts path before query', () {
      const url =
          'https://example.supabase.co/storage/v1/object/sign/meal-images/user/photo.jpg?token=abc123';
      expect(extractStoragePath(url, bucket), 'user/photo.jpg');
    });

    test('other storage URL format', () {
      const url =
          'https://example.supabase.co/storage/v1/object/authenticated/meal-images/user/photo.jpg';
      expect(extractStoragePath(url, bucket), 'user/photo.jpg');
    });

    test('nested path with subdirectories', () {
      const url =
          'https://example.supabase.co/storage/v1/object/public/meal-images/a/b/c.jpg';
      expect(extractStoragePath(url, bucket), 'a/b/c.jpg');
    });

    test('unrecognized URL returns original string', () {
      const url = 'https://example.com/some/other/path.jpg';
      expect(extractStoragePath(url, bucket), url);
    });
  });
}
