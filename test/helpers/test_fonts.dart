import 'dart:io';
import 'dart:typed_data';

/// The Flutter SDK's Roboto in [face] („Regular", „Bold", …), which every
/// `flutter test` run has.
File robotoFile(String face) => File(
  '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
  'material_fonts/Roboto-$face.ttf',
);

/// Where the table [tag] („hmtx", „OS/2", …) starts in the TrueType
/// [font].
int sfntTable(Uint8List font, String tag) {
  final data = ByteData.sublistView(font);
  for (var i = 0; i < data.getUint16(4); i++) {
    final record = 12 + 16 * i;
    if (String.fromCharCodes(font, record, record + 4) == tag) {
      return data.getUint32(record + 8);
    }
  }
  throw StateError('no $tag table');
}
