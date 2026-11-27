import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_glyph.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';

// The stroke as the canvas stores it (float32).
final _stroke =
    (Paint()..strokeWidth = AppConstants.drinkGlyphStroke).strokeWidth;

void main() {
  Future<void> pump(WidgetTester tester, Widget glyph) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: glyph),
    ),
  );

  testWidgets('every icon and vessel paints without errors at its size', (
    tester,
  ) async {
    for (final icon in DrinkIcon.values) {
      for (final size in [
        AppConstants.drinkTileIconSize,
        AppConstants.drinkRowIconSize,
      ]) {
        await pump(
          tester,
          DrinkGlyph.icon(icon, key: const Key('g'), size: size),
        );
        expect(tester.takeException(), isNull, reason: '$icon at $size');
        expect(tester.getSize(find.byKey(const Key('g'))), Size.square(size));
      }
    }
    for (final vessel in DrinkVessel.values) {
      await pump(tester, DrinkGlyph.vessel(vessel, key: const Key('g')));
      expect(tester.takeException(), isNull, reason: '$vessel');
      expect(
        tester.getSize(find.byKey(const Key('g'))),
        DrinkGlyph.vesselSize(vessel),
      );
    }
  });

  test('vessel sizes are the mockup boxes', () {
    expect(DrinkGlyph.vesselSize(DrinkVessel.glass), const Size(22, 28));
    expect(DrinkGlyph.vesselSize(DrinkVessel.can), const Size(20, 34));
    expect(DrinkGlyph.vesselSize(DrinkVessel.bottle), const Size(18, 40));
    expect(DrinkGlyph.vesselSize(DrinkVessel.large), const Size(24, 46));
  });

  testWidgets('a glyph has no semantics node', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DrinkGlyph.icon(DrinkIcon.hotCup),
          DrinkGlyph.vessel(DrinkVessel.large),
        ],
      ),
    );
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    handle.dispose();
  });

  testWidgets('strokes the outline in the given colour, unfilled', (
    tester,
  ) async {
    await pump(
      tester,
      const DrinkGlyph.icon(
        DrinkIcon.bottle,
        key: Key('g'),
        color: AppTheme.infoText,
      ),
    );
    final box = tester.renderObject(
      find.descendant(
        of: find.byKey(const Key('g')),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      box,
      paints..path(
        style: PaintingStyle.stroke,
        strokeWidth: _stroke,
        color: AppTheme.infoText,
      ),
    );
    expect(box, isNot(paints..path(style: PaintingStyle.fill)));
  });

  test('repaints only when what it draws changes', () {
    const a = DrinkGlyphPainter(
      icon: DrinkIcon.cup,
      color: AppTheme.foreground,
    );
    expect(
      a.shouldRepaint(
        const DrinkGlyphPainter(
          icon: DrinkIcon.cup,
          color: AppTheme.foreground,
        ),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        const DrinkGlyphPainter(
          icon: DrinkIcon.can,
          color: AppTheme.foreground,
        ),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const DrinkGlyphPainter(icon: DrinkIcon.cup, color: AppTheme.infoText),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const DrinkGlyphPainter(
          vessel: DrinkVessel.can,
          color: AppTheme.foreground,
        ),
      ),
      isTrue,
    );
  });
}
