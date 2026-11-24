import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/ambient_animations.dart';

Widget _wrap(Widget flame, {bool ticking = true}) => MaterialApp(
  theme: AppTheme.theme,
  home: Scaffold(
    body: Center(
      child: TickerMode(enabled: ticking, child: flame),
    ),
  ),
);

Widget _flame({
  int streak = 5,
  bool lit = true,
  double height = 40,
  bool igniteOnMount = false,
}) => StreakFlame(
  streak: streak,
  lit: lit,
  height: height,
  igniteOnMount: igniteOnMount,
);

FlamePainter _painter(WidgetTester t) =>
    t
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(StreakFlame),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as FlamePainter;

/// The ember's opacity along its breath (1 when it holds still).
double _breath(WidgetTester t) => t
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(StreakFlame),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

/// A canvas that scales the body by [scale] (about its base).
PaintPattern _scalesBody(double scale) => paints
  ..something(
    (method, args) =>
        method == #scale && ((args[0] as double) - scale).abs() < 1e-9,
  );

RenderObject _canvas(WidgetTester t) => t.renderObject(
  find.descendant(
    of: find.byType(StreakFlame),
    matching: find.byType(CustomPaint),
  ),
);

/// A canvas that fills a path with [color].
PaintPattern _fillsPath(Color color) => paints
  ..something(
    (method, args) =>
        method == #drawPath &&
        (args[1] as Paint).style == PaintingStyle.fill &&
        (args[1] as Paint).color.toARGB32() == color.toARGB32(),
  );

/// A canvas that fills a circle with [color].
PaintPattern _fillsCircle(Color color) => paints
  ..something(
    (method, args) =>
        method == #drawCircle &&
        (args[2] as Paint).style == PaintingStyle.fill &&
        (args[2] as Paint).color.toARGB32() == color.toARGB32(),
  );

void main() {
  test('tiers by streak', () {
    expect(StreakFlame.tierOf(0), FlameTier.small);
    expect(StreakFlame.tierOf(2), FlameTier.small);
    expect(StreakFlame.tierOf(3), FlameTier.medium);
    expect(StreakFlame.tierOf(6), FlameTier.medium);
    expect(StreakFlame.tierOf(7), FlameTier.large);
    expect(StreakFlame.tierOf(29), FlameTier.large);
    expect(StreakFlame.tierOf(30), FlameTier.blazing);
  });

  testWidgets('looks: lit, ember, off', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
    expect(_painter(t).look, FlameLook.lit);
    expect(_canvas(t), _fillsPath(AppTheme.streakFlame));
    expect(_canvas(t), _fillsPath(AppTheme.streakFlameCore));

    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    expect(_painter(t).look, FlameLook.ember);
    expect(_canvas(t), _fillsPath(AppTheme.streakEmber));
    expect(_canvas(t), _fillsPath(AppTheme.streakEmberCore));
    expect(_canvas(t), isNot(_fillsPath(AppTheme.streakFlame)));

    await t.pumpWidget(_wrap(_flame(streak: 0, lit: false)));
    expect(_painter(t).look, FlameLook.off);
    expect(_canvas(t), _fillsPath(AppTheme.streakEmberOff));
    expect(_canvas(t), isNot(_fillsPath(AppTheme.streakEmberCore)));
  });

  testWidgets('the blazing flame has its hot core and sparks', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 30)));
    expect(_painter(t).tier, FlameTier.blazing);
    expect(_canvas(t), _fillsPath(AppTheme.streakFlameHot));
    expect(_canvas(t), _fillsCircle(AppTheme.streakFlameCore));

    await t.pumpWidget(_wrap(_flame(streak: 29)));
    expect(_painter(t).tier, FlameTier.large);
    expect(_canvas(t), isNot(_fillsPath(AppTheme.streakFlameHot)));
    expect(_canvas(t), isNot(_fillsCircle(AppTheme.streakFlameCore)));
  });

  testWidgets('ember and off are drawn at 0.8 of their tier', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
    expect(_canvas(t), _scalesBody(FlameTier.medium.scale));

    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    expect(_canvas(t), _scalesBody(FlameTier.medium.scale * 0.8));

    await t.pumpWidget(_wrap(_flame(streak: 0, lit: false)));
    expect(_canvas(t), _scalesBody(FlameTier.small.scale * 0.8));
  });

  testWidgets('size keeps the 100:120 shape', (t) async {
    await t.pumpWidget(_wrap(_flame(height: 24)));
    expect(t.getSize(find.byType(StreakFlame)), const Size(20, 24));
  });

  testWidgets('ember → lit plays one burst, repainting the same painter', (
    t,
  ) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    expect(_painter(t).burst, isNull);

    await t.pumpWidget(_wrap(_flame(streak: 6, lit: true)));
    final painter = _painter(t);
    expect(painter.look, FlameLook.lit);
    await t.pump(const Duration(milliseconds: 150));
    expect(painter.burst, greaterThan(0));
    await t.pump(const Duration(milliseconds: 150));
    expect(painter.burst, greaterThan(0));
    expect(_painter(t), same(painter));

    await t.pump(const Duration(milliseconds: 500));
    expect(_painter(t).burst, isNull);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets("the ignite starts at the ember's size, without a full-size "
      'frame', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    await t.pumpWidget(_wrap(_flame(streak: 6, lit: true)));

    expect(_painter(t).burst, 0);
    expect(_canvas(t), _scalesBody(FlameTier.medium.scale * 0.8));
    expect(_canvas(t), isNot(_scalesBody(FlameTier.medium.scale)));
  });

  testWidgets('lit → ember: no burst', (t) async {
    // Today's first entry ignited the flame and was deleted again.
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    await t.pumpWidget(_wrap(_flame(streak: 6, lit: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).burst, greaterThan(0));

    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    await t.pump();
    expect(_painter(t).look, FlameLook.ember);
    expect(_painter(t).burst, isNull);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('igniteOnMount bursts once on the first build', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 1, igniteOnMount: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).look, FlameLook.lit);
    expect(_painter(t).burst, greaterThan(0));
    await t.pumpAndSettle();
    expect(_painter(t).burst, isNull);

    // A rebuild does not ignite it again.
    await t.pumpWidget(_wrap(_flame(streak: 1, igniteOnMount: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).burst, isNull);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('a flame lit from the start does not burst', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).burst, isNull);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('an ignite while hidden plays once visible', (t) async {
    await t.pumpWidget(_wrap(_flame(lit: false), ticking: false));
    await t.pumpWidget(_wrap(_flame(lit: true), ticking: false));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).look, FlameLook.lit);
    expect(_painter(t).burst, isNull);
    await t.pump(const Duration(seconds: 2));
    expect(_painter(t).burst, isNull);

    await t.pumpWidget(_wrap(_flame(lit: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).burst, greaterThan(0));
    await t.pumpAndSettle();
    expect(_painter(t).burst, isNull);

    // Once played, hiding and showing it again does not replay it.
    await t.pumpWidget(_wrap(_flame(lit: true), ticking: false));
    await t.pumpWidget(_wrap(_flame(lit: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).burst, isNull);
  });

  group('reduced motion', () {
    setUp(() => StreakFlame.ambientEnabled = true);
    tearDown(disableAmbientAnimationsForTests);

    testWidgets('lit at once, no burst, no wobble', (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await t.pumpWidget(_wrap(_flame(streak: 30, lit: false)));
      expect(_breath(t), 1);
      await t.pumpWidget(_wrap(_flame(streak: 31, lit: true)));
      await t.pump();

      final painter = _painter(t);
      expect(painter.look, FlameLook.lit);
      expect(painter.burst, isNull);
      expect(painter.wobble, 0);
      expect(t.binding.hasScheduledFrame, isFalse);

      // A fresh flame that would ignite on mount is lit at once too.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        _wrap(_flame(streak: 1, lit: true, igniteOnMount: true)),
      );
      await t.pump();
      expect(_painter(t).look, FlameLook.lit);
      expect(_painter(t).burst, isNull);
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  group('ambient', () {
    tearDown(disableAmbientAnimationsForTests);

    testWidgets('off in tests: still', (t) async {
      await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
      expect(t.hasRunningAnimations, isFalse);
      expect(_painter(t).wobble, 0);

      await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
      expect(t.hasRunningAnimations, isFalse);
      expect(_breath(t), 1);
    });

    testWidgets('on, it wobbles, the ember breathes, sparks rise', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 300));
      final wobble = _painter(t).wobble;
      expect(wobble, isNot(0));
      expect(wobble.abs(), lessThanOrEqualTo(1));

      // The ember breathes in its opacity; the painting holds still.
      await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
      await t.pump(const Duration(milliseconds: 300));
      final breath = _breath(t);
      expect(breath, inInclusiveRange(0, 1));
      expect(breath, lessThan(1));
      expect(_painter(t).clock, isNull);

      await t.pumpWidget(_wrap(_flame(streak: 30, lit: true)));
      await t.pump(const Duration(milliseconds: 300));
      final rise = _painter(t).rise;
      await t.pump(const Duration(milliseconds: 300));
      expect(_painter(t).rise, isNot(rise));

      // Not with nothing to show: no flame yet.
      await t.pumpWidget(_wrap(_flame(streak: 0, lit: false)));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('the mark stays still', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(const StreakFlame.mark(height: 20)));
      expect(t.hasRunningAnimations, isFalse);
      final painter = _painter(t);
      expect(painter.look, FlameLook.lit);
      expect(painter.tier, FlameTier.large);
      expect(painter.wobble, 0);
      // Only painted: no layer, fade or ticker of its own.
      expect(
        find.descendant(
          of: find.byType(StreakFlame),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });
}
