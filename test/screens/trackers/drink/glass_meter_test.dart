import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/glass_meter.dart';

// The stroke as the canvas stores it (float32).
final _stroke =
    (Paint()..strokeWidth = AppConstants.drinkGlyphStroke).strokeWidth;

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int drunk,
    required int pending,
    bool reducedMotion = false,
    double width = 342,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: GlassMeter(drunkMl: drunk, pendingMl: pending),
          ),
        ),
      ),
    ),
  );

  Finder glassFinder() => find.descendant(
    of: find.byKey(GlassMeter.glassesKey),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is GlassPainter,
    ),
  );

  List<GlassPainter> painters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(glassFinder())
      .map((c) => c.painter! as GlassPainter)
      .toList();

  testWidgets('GlassMeter is one image with the spoken summary', (t) async {
    final handle = t.ensureSemantics();
    await pump(t, drunk: 1000, pending: 400);
    expect(
      t.getSemantics(find.byKey(GlassMeter.glassesKey)),
      isSemantics(
        isImage: true,
        label: '4 Gläser zu je 250 ml getrunken, dazu kommen 400 ml',
      ),
    );
    handle.dispose();
  });

  testWidgets('GlassMeter draws one painter per glass with its fill', (
    tester,
  ) async {
    await pump(tester, drunk: 1100, pending: 400);
    final p = painters(tester);
    expect(p, hasLength(6));
    expect(p[4].fill.drunk, closeTo(0.4, 1e-9));
    expect(p[4].fill.pending, closeTo(0.6, 1e-9));
    for (final glass in tester.widgetList<CustomPaint>(glassFinder())) {
      expect(glass.size, AppConstants.glassMeterGlassSize);
    }
  });

  testWidgets('0 ml shows one empty glass with a solid outline', (
    tester,
  ) async {
    await pump(tester, drunk: 0, pending: 0);
    final p = painters(tester);
    expect(p, hasLength(1));
    expect(p.single.fill, (drunk: 0.0, pending: 0.0));
    expect(p.single.dashed, isFalse);
  });

  testWidgets('only a glass that is all pending has the dashed outline', (
    tester,
  ) async {
    await pump(tester, drunk: 1100, pending: 400);
    expect(
      [for (final p in painters(tester)) p.dashed],
      [false, false, false, false, false, true],
    );
  });

  testWidgets('20 l wraps onto more rows and stops at 48 glasses', (
    tester,
  ) async {
    await pump(tester, drunk: 20000, pending: 0);
    expect(tester.takeException(), isNull);
    expect(painters(tester), hasLength(AppConstants.glassMeterMaxGlasses));
    final tops = {
      for (final e in glassFinder().evaluate())
        tester.getTopLeft(find.byElementPredicate((x) => x == e)).dy,
    };
    expect(tops.length, greaterThan(1));
  });

  testWidgets('a new amount animates in', (tester) async {
    await pump(tester, drunk: 0, pending: 100);
    await pump(tester, drunk: 0, pending: 200);
    expect(painters(tester).single.fill.pending, lessThan(0.8));
    await tester.pumpAndSettle();
    expect(painters(tester).single.fill.pending, closeTo(0.8, 1e-9));
  });

  testWidgets('with reduced motion a new amount shows at once', (tester) async {
    await pump(tester, drunk: 0, pending: 100, reducedMotion: true);
    await pump(tester, drunk: 0, pending: 200, reducedMotion: true);
    expect(painters(tester).single.fill.pending, closeTo(0.8, 1e-9));
  });

  group('GlassPainter', () {
    Future<RenderObject> paintGlass(
      WidgetTester tester,
      GlassPainter painter,
    ) async {
      await tester.pumpWidget(
        Center(
          child: CustomPaint(
            key: const Key('glass'),
            size: AppConstants.glassMeterGlassSize,
            painter: painter,
          ),
        ),
      );
      return tester.renderObject(find.byKey(const Key('glass')));
    }

    testWidgets('fills drunk then pending and outlines in foreground', (
      tester,
    ) async {
      final box = await paintGlass(
        tester,
        const GlassPainter((drunk: 0.4, pending: 0.6)),
      );
      expect(
        box,
        paints
          ..rect(color: AppTheme.buddyWater)
          ..rect(color: AppTheme.careWaterSoft)
          ..path(
            style: PaintingStyle.stroke,
            color: AppTheme.foreground,
            strokeWidth: _stroke,
          ),
      );
    });

    testWidgets('an all-pending glass has a dashed infoText outline', (
      tester,
    ) async {
      const painter = GlassPainter((drunk: 0.0, pending: 0.4));
      expect(painter.dashed, isTrue);
      final box = await paintGlass(tester, painter);
      expect(
        box,
        paints
          ..rect(color: AppTheme.careWaterSoft)
          ..path(style: PaintingStyle.stroke, color: AppTheme.infoText),
      );
      expect(box, isNot(paints..rect(color: AppTheme.buddyWater)));
    });

    test('repaints only when the fill changes', () {
      const a = GlassPainter((drunk: 0.5, pending: 0.0));
      expect(
        a.shouldRepaint(const GlassPainter((drunk: 0.5, pending: 0.0))),
        isFalse,
      );
      expect(
        a.shouldRepaint(const GlassPainter((drunk: 0.5, pending: 0.1))),
        isTrue,
      );
    });
  });
}
