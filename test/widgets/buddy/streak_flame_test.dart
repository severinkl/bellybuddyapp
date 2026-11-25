import 'dart:ui' as ui;

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

/// The bounds of what [painter] paints into its box at [box]'s size,
/// relative to the box (null when it paints nothing).
Future<Rect?> _paintedBounds(FlamePainter painter, Size box) async {
  // A margin as large as the box on every side catches anything outside it.
  final width = box.width.ceil() * 3;
  final height = box.height.ceil() * 3;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(box.width, box.height);
  painter.paint(canvas, box);
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData())!;
  image.dispose();
  int? left, top, right, bottom;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (bytes.getUint8((y * width + x) * 4 + 3) == 0) continue;
      left = left == null || x < left ? x : left;
      right = right == null || x > right ? x : right;
      top ??= y;
      bottom = y;
    }
  }
  if (left == null) return null;
  return Rect.fromLTRB(
    left - box.width,
    top! - box.height,
    right! + 1 - box.width,
    bottom! + 1 - box.height,
  );
}

/// The colours (red, blue) down the column at [x] of what [painter]
/// paints at [size], top to bottom.
Future<List<(int, int)>> _column(
  FlamePainter painter,
  Size size, {
  required int x,
}) async {
  final width = size.width.ceil();
  final height = size.height.ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  image.dispose();
  return [
    for (var y = 0; y < height; y++)
      (
        bytes.getUint8((y * width + x) * 4),
        bytes.getUint8((y * width + x) * 4 + 2),
      ),
  ];
}

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

  test('lodert is taller than wide; the others keep their shape', () {
    expect(FlameTier.blazing.scaleY, greaterThan(FlameTier.blazing.scaleX));
    for (final tier in [FlameTier.small, FlameTier.medium, FlameTier.large]) {
      expect(tier.scaleX, tier.scaleY, reason: tier.name);
    }
  });

  testWidgets('looks: lit once today counts, else an ember, also at '
      'streak 0', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
    expect(_painter(t).look, FlameLook.lit);

    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    expect(_painter(t).look, FlameLook.ember);

    await t.pumpWidget(_wrap(_flame(streak: 0, lit: false)));
    expect(_painter(t).look, FlameLook.ember);
  });

  testWidgets('the ember is low: its tier squashed to 0.8 × 0.4, without '
      'sparks, hot core or glow', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
    final painter = _painter(t);
    expect(painter.tier, FlameTier.medium);
    expect(painter.bodyScale, const Size(0.8 * 0.8, 0.8 * 0.4));
    expect(painter.sparkCount, 0);
    expect(painter.hotCore, isFalse);
    expect(painter.showsGlow(const Size(100, 120)), isFalse);
    expect(painter.flicker, everyElement(0));
  });

  testWidgets('brennt: at least three tongues and sparks, no hot core', (
    t,
  ) async {
    // Sparks rise only while it moves.
    StreakFlame.ambientEnabled = true;
    addTearDown(disableAmbientAnimationsForTests);
    await t.pumpWidget(_wrap(_flame(streak: 7, lit: true)));
    final painter = _painter(t);
    expect(FlamePainter.tongueCount, greaterThanOrEqualTo(3));
    expect(painter.flicker, hasLength(FlamePainter.tongueCount));
    expect(painter.tier, FlameTier.large);
    expect(painter.sparkCount, 2);
    expect(painter.hotCore, isFalse);
    expect(painter.bodyScale, const Size(1, 1));
  });

  testWidgets('lodert: a hot core and more sparks', (t) async {
    StreakFlame.ambientEnabled = true;
    addTearDown(disableAmbientAnimationsForTests);
    await t.pumpWidget(_wrap(_flame(streak: 30)));
    final painter = _painter(t);
    expect(painter.tier, FlameTier.blazing);
    expect(painter.hotCore, isTrue);
    expect(painter.sparkCount, greaterThan(2));
  });

  testWidgets('lodert: its hot core is a soft blue root, without a hard '
      'edge', (t) async {
    // 2 px per unit of the 100 × 120 box: its base is at y 228, the bright
    // core's bottom edge just above y 221.
    final column = await t.runAsync(
      () => _column(
        FlamePainter(look: FlameLook.lit, tier: FlameTier.blazing),
        const Size(200, 240),
        x: 100,
      ),
    );
    int blueness(int y) => column![y].$2 - column[y].$1;
    // Blue at the root, cream higher up in the core …
    expect(blueness(218), greaterThan(0));
    expect(blueness(150), lessThan(0));
    // … fading between them, without a hard edge.
    for (var y = 218; y > 150; y--) {
      expect(
        (blueness(y - 1) - blueness(y)).abs(),
        lessThan(25),
        reason: 'from y $y up',
      );
    }
  });

  testWidgets('the glow from 40 dp up, only when lit', (t) async {
    await t.pumpWidget(_wrap(_flame(streak: 7, lit: true)));
    final painter = _painter(t);
    expect(painter.showsGlow(const Size(33.3, 39.9)), isFalse);
    expect(painter.showsGlow(const Size(33.4, 40)), isTrue);
  });

  testWidgets('at rest, every tier stays inside its box, sparks and '
      'flicker included', (t) async {
    const box = Size(100, 120);
    final clock = ValueNotifier(Duration.zero);
    addTearDown(clock.dispose);
    await t.runAsync(() async {
      for (final look in FlameLook.values) {
        for (final tier in FlameTier.values) {
          // Through a whole cycle of every tongue's flicker and the sparks.
          for (var ms = 0; ms < 1800; ms += 60) {
            clock.value = Duration(milliseconds: ms);
            final bounds = await _paintedBounds(
              FlamePainter(look: look, tier: tier, clock: clock),
              box,
            );
            final at = '$look, $tier at $ms ms';
            expect(bounds, isNotNull, reason: at);
            expect(
              (Offset.zero & box).intersect(bounds!),
              bounds,
              reason: '$at: $bounds',
            );
          }
        }
      }
    });
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
    expect(_painter(t).bodyScale, const Size(0.8 * 0.8, 0.8 * 0.4));
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

  testWidgets('lit in the frame that hides it: the ignite still waits', (
    t,
  ) async {
    await t.pumpWidget(_wrap(_flame(lit: false)));
    await t.pumpWidget(_wrap(_flame(lit: true), ticking: false));
    await t.pump(const Duration(seconds: 2));
    expect(_painter(t).burst, isNull);

    await t.pumpWidget(_wrap(_flame(lit: true)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_painter(t).burst, greaterThan(0));
  });

  group('reduced motion', () {
    setUp(() => StreakFlame.ambientEnabled = true);
    tearDown(disableAmbientAnimationsForTests);

    testWidgets('lit at once, no burst, no flicker', (t) async {
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
      expect(painter.flicker, everyElement(0));
      expect(painter.sparkCount, 0);
      expect(t.binding.hasScheduledFrame, isFalse);

      // A fresh flame that would ignite on mount is lit at once too.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        _wrap(_flame(streak: 1, lit: true, igniteOnMount: true)),
      );
      await t.pump();
      expect(_painter(t).look, FlameLook.lit);
      expect(_painter(t).burst, isNull);
      expect(_painter(t).flicker, everyElement(0));
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  group('ambient', () {
    tearDown(disableAmbientAnimationsForTests);

    testWidgets('off in tests: still', (t) async {
      await t.pumpWidget(_wrap(_flame(streak: 30, lit: true)));
      expect(t.hasRunningAnimations, isFalse);
      expect(_painter(t).flicker, everyElement(0));
      // A frozen spark would read as a speck of dirt.
      expect(_painter(t).sparkCount, 0);

      await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
      expect(t.hasRunningAnimations, isFalse);
      expect(_breath(t), 1);
    });

    testWidgets('on: the tongues flicker independently', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 300));
      final flicker = _painter(t).flicker;
      expect(flicker, everyElement(inInclusiveRange(-1, 1)));
      expect(flicker.toSet().length, greaterThanOrEqualTo(2));
      expect(flicker, isNot(everyElement(0)));

      await t.pump(const Duration(milliseconds: 250));
      expect(_painter(t).flicker, isNot(flicker));
    });

    testWidgets('the ember breathes', (t) async {
      StreakFlame.ambientEnabled = true;

      // The ember breathes in its opacity; the painting holds still.
      await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
      await t.pump(const Duration(milliseconds: 300));
      final breath = _breath(t);
      expect(breath, inInclusiveRange(0, 1));
      expect(breath, lessThan(1));
      expect(_painter(t).clock, isNull);
      expect(_painter(t).flicker, everyElement(0));
    });

    testWidgets('no sparks while it ignites', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(_flame(streak: 5, lit: false)));
      await t.pumpWidget(_wrap(_flame(streak: 6, lit: true)));
      expect(_painter(t).burst, 0);
      expect(_painter(t).sparkCount, 0);
      await t.pump(const Duration(milliseconds: 300));
      expect(_painter(t).burst, greaterThan(0));
      expect(_painter(t).sparkCount, 0);

      await t.pump(const Duration(milliseconds: 600));
      expect(_painter(t).burst, isNull);
      expect(_painter(t).sparkCount, 2);
    });

    testWidgets('sparks from 40 dp up, only while it moves', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(_flame(streak: 7, lit: true)));
      final moving = _painter(t);
      expect(moving.showsSparks(const Size(33.3, 39.9)), isFalse);
      expect(moving.showsSparks(const Size(33.4, 40)), isTrue);

      // The same flame held still: none at any size.
      disableAmbientAnimationsForTests();
      await t.pumpWidget(_wrap(_flame(streak: 7, lit: true, height: 41)));
      expect(_painter(t).showsSparks(const Size(100, 120)), isFalse);
    });

    testWidgets('sparks rise from brennt up', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(_flame(streak: 5, lit: true)));
      await t.pump(const Duration(milliseconds: 300));
      final rise = _painter(t).rise;
      expect(rise, isNotNull);
      await t.pump(const Duration(milliseconds: 300));
      expect(_painter(t).rise, isNot(rise));
    });

    testWidgets('the mark stays still', (t) async {
      StreakFlame.ambientEnabled = true;

      await t.pumpWidget(_wrap(const StreakFlame.mark(height: 20)));
      expect(t.hasRunningAnimations, isFalse);
      final painter = _painter(t);
      expect(painter.look, FlameLook.lit);
      expect(painter.tier, FlameTier.large);
      expect(painter.flicker, everyElement(0));
      expect(painter.sparkCount, 0);
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
