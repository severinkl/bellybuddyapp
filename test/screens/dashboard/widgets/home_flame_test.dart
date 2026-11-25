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

  /// A ring's box with his square in its middle (a middle [middleWidth]
  /// wide).
  ({Size ring, Rect buddy, Rect middle}) places(double middleWidth) {
    const ring = Size(600, 260);
    final middle = Rect.fromCenter(
      center: ring.center(Offset.zero),
      width: middleWidth,
      height: ring.height,
    );
    final buddy = Rect.fromCenter(
      center: middle.center,
      width: middleWidth < side ? middleWidth : side,
      height: side,
    );
    return (ring: ring, buddy: buddy, middle: middle);
  }

  /// His foot in the ring.
  Offset footIn(Rect buddy) =>
      buddy.topLeft + BuddyLayout(buddy.size).toLocal(kBuddyFoot);

  const shot = Key('shot');

  Future<({Rect buddy, Rect middle})> pump(
    WidgetTester tester, {
    required int streak,
    bool lit = false,
    double middleWidth = 400,
  }) async {
    final (:ring, :buddy, :middle) = places(middleWidth);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: shot,
            child: SizedBox.fromSize(
              size: ring,
              child: HomeFlame(
                streak: streak,
                lit: lit,
                buddy: buddy,
                middle: middle,
              ),
            ),
          ),
        ),
      ),
    );
    return (buddy: buddy, middle: middle);
  }

  testWidgets('the streak flame, larger than his square, without its core; '
      'its ignite stays inside its box', (tester) async {
    await pump(tester, streak: 12, lit: true);

    final flame = tester.widget<StreakFlame>(find.byType(StreakFlame));
    expect(flame.streak, 12);
    expect(flame.lit, isTrue);
    expect(flame.height, side * AppConstants.homeFlameScale);
    expect(flame.igniteOnMount, isFalse);
    // Its bright core would only show beside his stem.
    expect(flame.core, isFalse);
    expect(flame.contained, isTrue);
  });

  testWidgets('centred on his foot, its base a little below it; as wide as '
      'the middle leaves around his foot, less its blur', (tester) async {
    for (final middleWidth in [400.0, 170.0]) {
      final (:buddy, :middle) = await pump(
        tester,
        streak: 42,
        lit: true,
        middleWidth: middleWidth,
      );

      final foot = footIn(buddy);
      // Right of his square's middle, a little above its bottom.
      expect(foot.dx, greaterThan(buddy.center.dx));
      expect(foot.dy, lessThan(buddy.bottom));
      final flame = tester.getRect(find.byType(StreakFlame));
      expect(flame.center.dx, moreOrLessEquals(foot.dx));
      expect(
        flame.bottom - flame.height * FlamePainter.baseInset,
        moreOrLessEquals(foot.dy + side * AppConstants.homeFlameBelowFeet),
      );
      final room = 2 * (middle.right - foot.dx);
      expect(
        flame.width,
        moreOrLessEquals(room - 2 * 3 * AppConstants.homeFlameBlur),
        reason: '$middleWidth',
      );
    }
  });

  testWidgets('what it shows, blurred, stays in the middle', (tester) async {
    for (final (streak, lit) in [
      (42, true),
      (12, true),
      (2, true),
      (5, false),
    ]) {
      final (buddy: _, :middle) = await pump(
        tester,
        streak: streak,
        lit: lit,
        middleWidth: 170,
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shot),
      );
      final (bytes, width, height) = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        return (data, image.width, image.height);
      }))!;
      var left = width, right = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (bytes.getUint8((y * width + x) * 4 + 3) <= 2) continue;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
      final at = '$streak, $lit';
      expect(left, greaterThanOrEqualTo(middle.left.floor()), reason: at);
      expect(right, lessThan(middle.right.ceil()), reason: at);
    }
  });

  test('translucent by its look: an ember, brennt, lodert', () {
    for (final (streak, lit, expected) in [
      (5, false, AppConstants.homeFlameEmberOpacity),
      (0, false, AppConstants.homeFlameEmberOpacity),
      (30, false, AppConstants.homeFlameEmberOpacity),
      (5, true, AppConstants.homeFlameLitOpacity),
      (29, true, AppConstants.homeFlameLitOpacity),
      (30, true, AppConstants.homeFlameBlazingOpacity),
    ]) {
      expect(
        HomeFlame.opacityFor(streak: streak, lit: lit),
        expected,
        reason: '$streak, $lit',
      );
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

  testWidgets('blurred and faded in one filter layer', (tester) async {
    await pump(tester, streak: 30, lit: true);

    expect(
      find.ancestor(
        of: find.byType(StreakFlame),
        matching: find.byType(ImageFiltered),
      ),
      findsOneWidget,
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('in front of lodert he is opaque: inside his stem shows him, '
      'not the flame', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
                  behindBuddy: (buddy, middle) => HomeFlame(
                    streak: 42,
                    lit: true,
                    buddy: buddy,
                    middle: middle,
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
