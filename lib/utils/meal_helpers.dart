import 'dart:convert';
import 'dart:typed_data';

import 'mime_utils.dart';

abstract final class MealHelpers {
  /// Builds a data-URI (e.g. `data:image/jpeg;base64,...`) from raw bytes
  /// and a filename.
  static String buildImageBase64(Uint8List bytes, String filename) {
    final ext = filename.split('.').last.toLowerCase();
    final mimeType = mimeTypeForExtension(ext);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
}
