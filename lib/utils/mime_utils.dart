/// Maps common image file extensions to their proper MIME types.
String mimeTypeForExtension(String extension) {
  return switch (extension.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'application/octet-stream',
  };
}
