import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/home_flame.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/care_now.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_shape_data.dart'
    show kBuddyHeight;
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';

import '../../../helpers/flames.dart';
import '../../../helpers/pixels.dart';

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

  /// His height and the top of his head in the ring.
  double heightOf(Rect buddy) => kBuddyHeight * BuddyLayout(buddy.size).scale;
  double headIn(Rect buddy) => buddy.top + BuddyLayout(buddy.size).headTop;

  const shot = Key('shot');
  const band = AppConstants.homeHeadroom;

  /// The ring's box at [band] from the top of the shot, so the shot holds
  /// the band above the ring too.
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
            child: Padding(
              padding: const EdgeInsets.only(top: band),
              child: SizedBox.fromSize(
                size: ring,
                child: HomeFlame(
                  streak: streak,
                  lit: lit,
                  buddy: buddy,
                  middle: middle,
                  headroom: band,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (buddy: buddy, middle: middle);
  }

  /// Where the lit flame's tallest tip sits at rest, in the ring.
  double tipOf(WidgetTester tester) {
    final box = tester
        .getRect(find.byType(StreakFlame))
        .shift(const Offset(0, -band));
    final painter = flamePainter(tester);
    final base = box.bottom - box.height * FlamePainter.baseInset;
    return base - painter.bodyScale.height * FlamePainter.tipReach * box.height;
  }

  testWidgets('the streak flame, reaching as Home sizes it, without its '
      'core; its ignite stays inside its box', (tester) async {
    await pump(tester, streak: 12, lit: true);

    final flame = tester.widget<StreakFlame>(find.byType(StreakFlame));
    expect(flame.streak, 12);
    expect(flame.lit, isTrue);
    expect(flame.reach, isNotNull);
    expect(flame.igniteOnMount, isFalse);
    // Its bright core would only show beside his stem.
    expect(flame.core, isFalse);
    expect(flame.contained, isTrue);
  });

  testWidgets('its tips rise clearly above his head, by its tier (≥ 15 % '
      'of his height), its base a little below his foot; it never reaches '
      'past the band above the ring', (tester) async {
    final rises = <FlameTier, double>{};
    for (final (streak, tier) in [
      (1, FlameTier.small),
      (5, FlameTier.medium),
      (12, FlameTier.large),
      (42, FlameTier.blazing),
    ]) {
      final (:buddy, middle: _) = await pump(tester, streak: streak, lit: true);
      final height = heightOf(buddy);
      final rise = (headIn(buddy) - tipOf(tester)) / height;
      rises[tier] = rise;
      final at = '$tier';
      expect(rise, greaterThanOrEqualTo(0.15), reason: at);
      // As painted: its top shows above his head by that much.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shot),
      );
      final (bytes, width, height_) = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        return ((await image.toByteData())!, image.width, image.height);
      }))!;
      var top = height_;
      for (var y = 0; y < height_ && top == height_; y++) {
        for (var x = 0; x < width; x++) {
          if (pixelAt(bytes, width, x, y).a > 0.1) {
            top = y;
            break;
          }
        }
      }
      expect(
        top - band,
        lessThanOrEqualTo(headIn(buddy) - 0.15 * height),
        reason: '$at: painted top $top',
      );
      // Lodert as high as the band leaves (its flicker inside it).
      if (tier == FlameTier.blazing) {
        expect(rise, lessThanOrEqualTo(HomeFlame.riseFor(tier)), reason: at);
      } else {
        expect(rise, moreOrLessEquals(HomeFlame.riseFor(tier)), reason: at);
      }

      final box = tester.getRect(find.byType(StreakFlame));
      final foot = footIn(buddy);
      expect(
        box.bottom - band - box.height * FlamePainter.baseInset,
        moreOrLessEquals(foot.dy + side * AppConstants.homeFlameBelowFeet),
        reason: at,
      );
      // Its box (flicker and ignite inside it), blurred, stays below the
      // band's top.
      expect(
        box.top - 3 * AppConstants.homeFlameBlur,
        greaterThanOrEqualTo(-0.01),
        reason: at,
      );
    }
    // It grows with the streak.
    expect(rises[FlameTier.small], lessThan(rises[FlameTier.medium]!));
    expect(rises[FlameTier.medium], lessThan(rises[FlameTier.large]!));
    expect(rises[FlameTier.large], lessThan(rises[FlameTier.blazing]!));
  });

  testWidgets('without room in the band, its tips stop below its top', (
    tester,
  ) async {
    final (:ring, :buddy, :middle) = places(400);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: ring,
            child: HomeFlame(
              streak: 42,
              lit: true,
              buddy: buddy,
              middle: middle,
              headroom: 0,
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(StreakFlame));
    expect(
      box.top - 3 * AppConstants.homeFlameBlur,
      greaterThanOrEqualTo(-0.01),
    );
    // [tipOf] counts from a band above the ring; here there is none.
    expect(tipOf(tester) + band, greaterThanOrEqualTo(0));
    expect(tipOf(tester) + band, lessThan(headIn(buddy)));
  });

  testWidgets('offset to his right, beside his head; as wide as the middle '
      'leaves around it, less its blur', (tester) async {
    for (final middleWidth in [400.0, 170.0]) {
      final (:buddy, :middle) = await pump(
        tester,
        streak: 42,
        lit: true,
        middleWidth: middleWidth,
      );

      final foot = footIn(buddy);
      final flame = tester.getRect(find.byType(StreakFlame));
      final centre = foot.dx + AppConstants.homeFlameOffset * heightOf(buddy);
      expect(AppConstants.homeFlameOffset, greaterThan(0));
      expect(flame.center.dx, moreOrLessEquals(centre), reason: '$middleWidth');
      expect(flame.center.dx, greaterThan(buddy.center.dx));
      final room = 2 * math.min(centre - middle.left, middle.right - centre);
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
          if (pixelAt(bytes, width, x, y).a <= 2 / 255) continue;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
      final at = '$streak, $lit';
      expect(left, greaterThanOrEqualTo(middle.left.floor()), reason: at);
      expect(right, lessThan(middle.right.ceil()), reason: at);
    }
  });

  test('stronger than in round 5: barely translucent, a light blur', () {
    expect(AppConstants.homeFlameEmberOpacity, 0.95);
    expect(AppConstants.homeFlameLitOpacity, 0.85);
    expect(AppConstants.homeFlameBlazingOpacity, 0.9);
    expect(AppConstants.homeFlameBlur, 1.0);
  });

  test('its opacity by its look: an ember, brennt, lodert', () {
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
                    headroom: AppConstants.homeHeadroom,
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
      return pixelAt(bytes, imageWidth, p.dx.round(), p.dy.round());
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

  for (final phone in [
    (size: const Size(402, 874), textScale: 1.0),
    (size: const Size(375, 667), textScale: 1.3),
  ]) {
    testWidgets('${phone.size} at text scale ${phone.textScale}: every look '
        'stays clear of the need bubbles; its tips stay in the band above '
        'the ring', (tester) async {
      tester.view.physicalSize = phone.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = phone.textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final width = phone.size.width - 2 * AppConstants.spacingLg;
      final diameter = CareRing.diameterFor(width, phone.size.height);
      for (final (streak, lit) in [
        (5, false),
        (1, true),
        (5, true),
        (42, true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: band),
                  child: SizedBox(
                    width: width,
                    child: CareRing(
                      care: CareNow.at(
                        const CareLog(),
                        DateTime(2026, 11, 23, 14),
                      ),
                      diameter: diameter,
                      onNeed: (_) {},
                      behindBuddy: (buddy, middle) => RepaintBoundary(
                        key: shot,
                        child: HomeFlame(
                          streak: streak,
                          lit: lit,
                          buddy: buddy,
                          middle: middle,
                          headroom: band,
                        ),
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
        final at = '$streak, $lit';
        final ring = tester.getRect(find.byType(CareRing));
        final flame = tester.getRect(find.byType(StreakFlame));
        // Blurred, its box stays inside the band and the ring's middle.
        final painted = flame.inflate(3 * AppConstants.homeFlameBlur);
        expect(painted.top, greaterThanOrEqualTo(ring.top - band - 0.01));
        for (final need in CareNeed.values) {
          final bubble = tester.getRect(find.byKey(CareRing.needKey(need)));
          expect(
            painted.overlaps(bubble),
            isFalse,
            reason: '$at: $need $bubble, flame $painted',
          );
        }

        // What it paints in the ring, pixel by pixel.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(shot),
        );
        final origin = boundary.localToGlobal(Offset.zero);
        final (bytes, imageWidth, imageHeight) = (await tester.runAsync(
          () async {
            final image = await boundary.toImage();
            final data = (await image.toByteData())!;
            return (data, image.width, image.height);
          },
        ))!;
        for (final need in CareNeed.values) {
          final bubble = tester
              .getRect(find.byKey(CareRing.needKey(need)))
              .shift(-origin);
          var seen = 0;
          for (var y = bubble.top.ceil(); y < bubble.bottom.floor(); y++) {
            for (var x = bubble.left.ceil(); x < bubble.right.floor(); x++) {
              if (x < 0 || y < 0 || x >= imageWidth || y >= imageHeight) {
                continue;
              }
              if (pixelAt(bytes, imageWidth, x, y).a > 2 / 255) seen++;
            }
          }
          expect(seen, 0, reason: '$at: $need');
        }
      }
    });
  }
}
