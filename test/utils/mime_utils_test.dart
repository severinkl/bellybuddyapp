import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/mime_utils.dart';

void main() {
  group('mimeTypeForExtension', () {
    test('maps jpg to image/jpeg', () {
      expect(mimeTypeForExtension('jpg'), 'image/jpeg');
    });

    test('maps jpeg to image/jpeg', () {
      expect(mimeTypeForExtension('jpeg'), 'image/jpeg');
    });

    test('maps png to image/png', () {
      expect(mimeTypeForExtension('png'), 'image/png');
    });

    test('maps gif to image/gif', () {
      expect(mimeTypeForExtension('gif'), 'image/gif');
    });

    test('maps webp to image/webp', () {
      expect(mimeTypeForExtension('webp'), 'image/webp');
    });

    test('maps heic to image/heic', () {
      expect(mimeTypeForExtension('heic'), 'image/heic');
    });

    test('maps heif to image/heif', () {
      expect(mimeTypeForExtension('heif'), 'image/heif');
    });

    test('is case insensitive', () {
      expect(mimeTypeForExtension('JPG'), 'image/jpeg');
      expect(mimeTypeForExtension('PNG'), 'image/png');
    });

    test('returns octet-stream for unknown extensions', () {
      expect(mimeTypeForExtension('xyz'), 'application/octet-stream');
      expect(mimeTypeForExtension('bmp'), 'application/octet-stream');
    });
  });
}
