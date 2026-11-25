import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/home_flame.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/care_now.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';

void main() {
  const side = 192.0;

  /// How far right of his square's middle his foot stands.
  final footDx =
      BuddyLayout(const Size.square(side)).toLocal(kBuddyFoot).dx - side / 2;

  Future<void> pump(
    WidgetTester tester, {
    required int streak,
    bool lit = false,
    double middleWidth = 1000,
  }) => tester.pumpWidget(
    Center(
      child: HomeFlame(
        streak: streak,
        lit: lit,
        buddySide: side,
        middleWidth: middleWidth,
      ),
    ),
  );

  /// The backdrop filter: blurred, then faded to [opacity].
  ImageFilter backdrop(double opacity) => ImageFilter.compose(
    outer: ColorFilter.mode(
      Colors.black.withValues(alpha: opacity),
      BlendMode.dstIn,
    ),
    inner: ImageFilter.blur(
      sigmaX: AppConstants.homeFlameBlur,
      sigmaY: AppConstants.homeFlameBlur,
      // Clear beyond it: no smeared edges.
      tileMode: TileMode.decal,
    ),
  );

  ImageFilter filterOf(WidgetTester tester) => tester
      .widget<ImageFiltered>(
        find.ancestor(
          of: find.byType(StreakFlame),
          matching: find.byType(ImageFiltered),
        ),
      )
      .imageFilter;

  testWidgets('the streak flame, larger than his square', (tester) async {
    await pump(tester, streak: 12, lit: true);

    final flame = tester.widget<StreakFlame>(find.byType(StreakFlame));
    expect(flame.streak, 12);
    expect(flame.lit, isTrue);
    expect(flame.height, side * AppConstants.homeFlameScale);
    // It moves: its motion is Home's.
    expect(flame.still, isFalse);
    expect(flame.igniteOnMount, isFalse);
    // Its bright core would only show beside his stem.
    expect(flame.core, isFalse);
  });

  testWidgets("fits the ring's middle: as tall, but no wider than the middle "
      'leaves around his foot, and only where it must', (tester) async {
    const height = side * AppConstants.homeFlameScale;
    const own = height * FlamePainter.aspectRatio;
    double drawn(FlameLook look, FlameTier tier) =>
        own * FlamePainter.widthShare(look: look, tier: tier, height: height);

    // A wide middle: its own shape.
    await pump(tester, streak: 42, lit: true);
    var flame = tester.getRect(find.byType(StreakFlame));
    expect(flame.height, moreOrLessEquals(height));
    expect(flame.width, moreOrLessEquals(own));

    // A narrow one: what it draws just fits, as tall.
    const middle = 170.0;
    final room = middle - 2 * footDx;
    for (final (streak, tier) in [
      (42, FlameTier.blazing),
      (12, FlameTier.large),
    ]) {
      expect(drawn(FlameLook.lit, tier), greaterThan(room));
      await pump(tester, streak: streak, lit: true, middleWidth: middle);
      flame = tester.getRect(find.byType(StreakFlame));
      expect(flame.height, moreOrLessEquals(height));
      expect(
        flame.width,
        moreOrLessEquals(own * room / drawn(FlameLook.lit, tier)),
        reason: '$tier',
      );
    }
    // Smaller ones and the ember already fit: their own shape.
    for (final (streak, lit) in [(5, true), (2, true), (42, false)]) {
      expect(
        drawn(
          lit ? FlameLook.lit : FlameLook.ember,
          StreakFlame.tierOf(streak),
        ),
        lessThanOrEqualTo(room),
      );
      await pump(tester, streak: streak, lit: lit, middleWidth: middle);
      expect(
        tester.getRect(find.byType(StreakFlame)).width,
        moreOrLessEquals(own),
        reason: '$streak, $lit',
      );
    }
  });

  testWidgets('a backdrop: translucent by its look (an ember, brennt, '
      'lodert) in one blurring filter', (tester) async {
    for (final (streak, lit, expected) in [
      (5, false, AppConstants.homeFlameEmberOpacity),
      (0, false, AppConstants.homeFlameEmberOpacity),
      (30, false, AppConstants.homeFlameEmberOpacity),
      (5, true, AppConstants.homeFlameLitOpacity),
      (29, true, AppConstants.homeFlameLitOpacity),
      (30, true, AppConstants.homeFlameBlazingOpacity),
    ]) {
      await pump(tester, streak: streak, lit: lit);
      expect(filterOf(tester), backdrop(expected), reason: '$streak, $lit');
      // No layer of its own for the opacity.
      expect(find.byType(Opacity), findsNothing);
    }
    expect(
      AppConstants.homeFlameLitOpacity,
      lessThan(AppConstants.homeFlameBlazingOpacity),
    );
    expect(
      AppConstants.homeFlameBlazingOpacity,
      lessThan(AppConstants.homeFlameEmberOpacity),
    );
  });

  testWidgets('in front of lodert he is opaque: inside his stem shows him, '
      'not the flame', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const shot = Key('shot');
    const width = 402.0 - 2 * AppConstants.spacingLg;
    final diameter = CareRing.diameterFor(width, 874);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: shot,
              child: SizedBox(
                width: width,
                child: CareRing(
                  care: CareNow.at(const CareLog(), DateTime(2026, 11, 23, 14)),
                  diameter: diameter,
                  onNeed: (_) {},
                  behindBuddy: HomeFlame(
                    streak: 42,
                    lit: true,
                    buddySide: diameter * AppConstants.careRingBuddyFactor,
                    middleWidth: CareRing.middleWidthFor(width),
                  ),
                  buddy: AnimatedBuddy(
                    controller: BuddyController(),
                    name: 'Bubu',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    final origin = boundary.localToGlobal(Offset.zero);
    final square = tester.getRect(find.byKey(CareRing.buddyKey));
    final layout = BuddyLayout(square.size);
    const ratio = 4.0;
    final (data, imageWidth) = (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      return (await image.toByteData(), image.width);
    }))!;
    final bytes = data!;

    /// The colour drawn at [imagePoint] of the Buddy.
    Color at(Offset imagePoint) {
      final p = (square.topLeft + layout.toLocal(imagePoint) - origin) * ratio;
      final i = (p.dy.round() * imageWidth + p.dx.round()) * 4;
      return Color.fromARGB(
        bytes.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    }

    // Inside his stem's left outline: his white, as on a white page.
    for (final p in const [Offset(722, 1860), Offset(722, 1780)]) {
      expect(at(p), Colors.white, reason: '$p');
    }
    // Beside his stem, the flame shows …
    final beside = at(const Offset(600, 1860));
    expect(beside.b, lessThan(0.9), reason: '$beside');
    // … warm, as its tongues' base: never the core's cream or the root's
    // blue in the gaps beside his stem, under his lowest loop.
    final gaps = [
      // Left of his stem, under his lowest loop.
      for (var y = 1680.0; y <= 1890; y += 15)
        for (var x = 560.0; x <= 630; x += 10) Offset(x, y),
      // Right of it, under his curl.
      for (var y = 1820.0; y <= 1890; y += 15)
        for (var x = 960.0; x <= 1020; x += 10) Offset(x, y),
    ];
    var seen = 0;
    for (final p in gaps) {
      final c = at(p);
      // The flame alone: translucent (he is opaque).
      if (c.a < 0.05 || c.a > 0.99) continue;
      seen++;
      // Unpremultiplied: what it shows over the page.
      final r = c.r / c.a, g = c.g / c.a, b = c.b / c.a;
      expect(r, greaterThanOrEqualTo(g), reason: '$p: $c');
      expect(g, greaterThan(b), reason: '$p: $c');
      expect(b / r, lessThan(0.7), reason: '$p: $c');
    }
    expect(seen, greaterThan(gaps.length ~/ 2));
  });
}
