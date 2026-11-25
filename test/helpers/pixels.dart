import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// The colour at ([x], [y]) of [rgba], an image [width] pixels wide with
/// four bytes per pixel (red, green, blue, alpha).
Color pixelAt(ByteData rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    rgba.getUint8(i + 3),
    rgba.getUint8(i),
    rgba.getUint8(i + 1),
    rgba.getUint8(i + 2),
  );
}
