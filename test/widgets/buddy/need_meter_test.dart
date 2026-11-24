import 'dart:math' as math;

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('fill deepens with the level', () {
    const painter = NeedMeterPainter(need: CareNeed.drink, level: 0.5);
    expect(
      painter.fill,
      Color.lerp(AppTheme.background, AppTheme.careWaterSoft, 0.5),
    );
    expect(painter.sweep, closeTo(math.pi, 1e-9));
  });

  test('each need draws in its own colour', () {
    expect(careColorsOf(CareNeed.food), (
      color: AppTheme.careFood,
      soft: AppTheme.careFoodSoft,
    ));
    expect(careColorsOf(CareNeed.drink), (
      color: AppTheme.careWater,
      soft: AppTheme.careWaterSoft,
    ));
    expect(careColorsOf(CareNeed.gutFeeling), (
      color: AppTheme.careGut,
      soft: AppTheme.careGutSoft,
    ));
    expect(careColorsOf(CareNeed.toilet), (
      color: AppTheme.careLoo,
      soft: AppTheme.careLooSoft,
    ));
  });

  test('Klo: a plain circle, no arc', () {
    const painter = NeedMeterPainter(need: CareNeed.toilet, level: null);
    expect(painter.sweep, 0);
    expect(painter.fill, AppTheme.careLooSoft);
  });

  testWidgets('the child is centred and scaled down to half the size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const NeedMeter(
          need: CareNeed.food,
          level: 0.8,
          size: 60,
          child: SizedBox(key: Key('c'), width: 200, height: 10),
        ),
      ),
    );
    // getSize is the unscaled layout size; the corners go through the
    // FittedBox's transform.
    final c = find.byKey(const Key('c'));
    expect(
      tester.getTopRight(c).dx - tester.getTopLeft(c).dx,
      lessThanOrEqualTo(30),
    );
    expect(
      tester.getCenter(find.byKey(const Key('c'))),
      tester.getCenter(find.byType(NeedMeter)),
    );
  });

  testWidgets('no semantics of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const NeedMeter(
          need: CareNeed.food,
          level: 0.8,
          size: 60,
          child: SizedBox(width: 10, height: 10),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(NeedMeter),
        matching: find.byType(Semantics),
      ),
      findsNothing,
    );
    expect(tester.semantics.simulatedAccessibilityTraversal(), isEmpty);
    handle.dispose();
  });
}
