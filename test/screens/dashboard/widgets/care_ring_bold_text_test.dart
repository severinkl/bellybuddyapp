import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/care_now.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';

/// The Flutter SDK's Roboto, which every `flutter test` run has.
File _roboto(String face) => File(
  '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
  'material_fonts/Roboto-$face.ttf',
);

/// [font] with its OS/2 weight class set to [weight].
Uint8List _withWeight(Uint8List font, int weight) {
  final data = ByteData.sublistView(font);
  final tables = data.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final record = 12 + 16 * i;
    if (String.fromCharCodes(font, record, record + 4) == 'OS/2') {
      data.setUint16(data.getUint32(record + 8) + 4, weight);
      return font;
    }
  }
  throw StateError('no OS/2 table');
}

/// Its own file: the fonts it loads stay loaded for the whole file.
void main() {
  final fonts = [_roboto('Regular'), _roboto('Black')];
  final available = fonts.every((f) => f.existsSync());

  setUpAll(() async {
    if (!available) return;
    // The theme's family with a semibold face (the labels' w600) a little
    // narrower than its bold one, as SF Pro's on iOS. The test font draws
    // every weight at one width, so it can't show bold text overflowing.
    ByteData face(File file, int weight) =>
        ByteData.sublistView(_withWeight(file.readAsBytesSync(), weight));
    final loader = FontLoader('.SF Pro Text')
      ..addFont(Future.value(face(fonts[0], 600)))
      ..addFont(Future.value(face(fonts[1], 700)));
    await loader.load();
  });

  testWidgets(
    'bold text at text scale 1.3: every label fits its bubble as drawn',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final now = DateTime(2026, 11, 23, 14);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CareRing(
                care: CareNow.at(const CareLog(), now),
                diameter: CareRing.diameterFor(375 - 32, 667),
                onNeed: (_) {},
                buddy: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      for (final need in CareNeed.values) {
        final label = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(CareRing.needKey(need)),
            matching: find.text(need.label),
          ),
        );
        expect(label.text.style?.fontWeight, FontWeight.bold, reason: '$need');
        expect(
          label.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(AppConstants.careNeedWidth),
          reason: '$need',
        );
      }
    },
    skip: !available,
  );
}
