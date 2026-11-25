import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/care_now.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/widgets/buddy/buddy_geometry.dart';
import 'package:belly_buddy/widgets/buddy/need_icon.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';

import '../../../helpers/widget_tester_helpers.dart';

DateTime _t(int h, [int m = 0, int d = 23]) => DateTime(2026, 11, d, h, m);

/// Essen's level at 14:00 after a meal at [meal] (its math is
/// care_meters_test's).
double _foodAt14(DateTime meal) =>
    CareMeters.at(CareLog(lastMealAt: meal), _t(14)).food;

void main() {
  var buddyTapsLog = <int>[];

  /// Pumps the ring at [now] (14:00 unless given); the needs its bubbles
  /// were tapped for land in the returned list, in order.
  Future<List<CareNeed>> pump(
    WidgetTester tester, {
    CareLog log = const CareLog(),
    DateTime? now,
    CareNeed? highlight,
    Size size = const Size(393, 852),
    double textScale = 1.0,
    Duration settle = const Duration(milliseconds: 400),
    Widget? behindBuddy,
    Widget? overBuddy,
    double overBuddyRoom = 0,
    Widget? buddy,
  }) async {
    final tapped = <CareNeed>[];
    final buddyTaps = <int>[];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final width = MediaQuery.sizeOf(context).width - 32;
                return CareRing(
                  care: CareNow.at(log, now ?? _t(14)),
                  diameter: CareRing.diameterFor(width, size.height),
                  highlight: highlight,
                  onNeed: tapped.add,
                  behindBuddy: behindBuddy,
                  overBuddy: overBuddy,
                  overBuddyRoom: overBuddyRoom,
                  buddy:
                      buddy ??
                      GestureDetector(
                        key: const Key('buddy_double'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => buddyTaps.add(1),
                        child: const ColoredBox(color: AppTheme.buddyBody),
                      ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(settle);
    buddyTapsLog = buddyTaps;
    return tapped;
  }

  Finder meterOf(CareNeed need) => find.descendant(
    of: find.byKey(CareRing.needKey(need)),
    matching: find.byType(NeedMeter),
  );

  /// The circle [need]'s meter draws (its glow reaches around it).
  Rect circle(WidgetTester tester, CareNeed need) =>
      tester.getRect(meterOf(need));

  Rect bubble(WidgetTester tester, CareNeed need) =>
      tester.getRect(find.byKey(CareRing.needKey(need)));

  test('diameter: at most 260, a share of width and height, at least 170', () {
    expect(CareRing.diameterFor(361, 852), closeTo(255.6, 0.01));
    expect(CareRing.diameterFor(1000, 2000), 260);
    expect(CareRing.diameterFor(343, 667), closeTo(200.1, 0.01));
    expect(CareRing.diameterFor(200, 400), 170);
  });

  test("its middle: the width between the bubbles' columns", () {
    expect(CareRing.middleWidthFor(354), 158);
    expect(CareRing.middleWidthFor(327), 131);
  });

  test('meter size: 27 % of the ring, between 48 and 72', () {
    expect(CareRing.meterSizeFor(255.6), closeTo(69.01, 0.005));
    expect(CareRing.meterSizeFor(200.1), closeTo(54.03, 0.005));
    expect(CareRing.meterSizeFor(170), 48);
    expect(CareRing.meterSizeFor(300), 72);
  });

  testWidgets('each metered need shows its level, Klo its last time', (
    tester,
  ) async {
    final log = CareLog(
      lastMealAt: _t(13),
      lastDrinkAt: _t(12, 30),
      lastGutFeelingAt: _t(8),
      lastToiletAt: _t(11),
    );
    await pump(tester, log: log);

    final meters = CareMeters.at(log, _t(14));
    for (final need in meteredNeeds) {
      expect(needMeterLevel(tester, need), meters.level(need), reason: '$need');
    }
    expect(needMeterLevel(tester, CareNeed.toilet), isNull);
    for (final need in CareNeed.values) {
      expect(
        find.descendant(
          of: find.byKey(CareRing.needKey(need)),
          matching: find.text(need.label),
        ),
        findsOneWidget,
        reason: '$need',
      );
    }
    expect(
      find.descendant(
        of: find.byKey(CareRing.needKey(CareNeed.toilet)),
        matching: find.text('vor 3 Std'),
      ),
      findsOneWidget,
    );
  });

  testWidgets("each bubble shows its need's sticker icon at the meter's icon "
      'size', (tester) async {
    await pump(tester, highlight: CareNeed.drink);

    for (final need in CareNeed.values) {
      final icon = tester.widget<NeedIcon>(
        find.descendant(of: meterOf(need), matching: find.byType(NeedIcon)),
      );
      expect(icon.need, need, reason: '$need');
      expect(
        icon.size,
        tester.getSize(meterOf(need)).width * AppConstants.careMeterIconShare,
        reason: '$need',
      );
    }
  });

  testWidgets("Klo before today's first entry: heute noch nicht", (
    tester,
  ) async {
    await pump(tester, log: CareLog(lastToiletAt: _t(22, 0, 22)));

    expect(
      find.descendant(
        of: find.byKey(CareRing.needKey(CareNeed.toilet)),
        matching: find.text('heute noch nicht'),
      ),
      findsOneWidget,
    );
  });

  testWidgets("Bauchgefühl shows today's latest level, not always a smile", (
    tester,
  ) async {
    NeedIcon gutIcon() => tester.widget<NeedIcon>(
      find.descendant(
        of: meterOf(CareNeed.gutFeeling),
        matching: find.byType(NeedIcon),
      ),
    );
    final handle = tester.ensureSemantics();
    for (final level in GutFeelingRatingLevel.values) {
      await pump(
        tester,
        log: CareLog(lastGutFeelingAt: _t(8), lastGutFeelingLevel: level),
      );
      expect(gutIcon().gutFeeling, level, reason: '$level');
      final node = tester.getSemantics(
        find.byKey(CareRing.needKey(CareNeed.gutFeeling)),
      );
      expect(node.value, 'zuletzt vor 6 Std, ${level.label}');
    }
    handle.dispose();
    // Each level its own mouth.
    expect({
      for (final level in GutFeelingRatingLevel.values)
        NeedIcon.assetFor(CareNeed.gutFeeling, gutFeeling: level),
    }, hasLength(4));

    // No entry yet: the plain belly.
    await pump(tester);
    expect(gutIcon().gutFeeling, isNull);
  });

  testWidgets('a bubble opens its own need: on its meter and on its lower '
      'edge', (tester) async {
    final tapped = await pump(tester);

    for (final need in CareNeed.values) {
      await tester.tapAt(circle(tester, need).center);
      // Just above the bubble's bottom, under its last line.
      final b = bubble(tester, need);
      await tester.tapAt(Offset(b.center.dx, b.bottom - 1));
    }
    expect(tapped, [
      for (final need in CareNeed.values) ...[need, need],
    ]);
  });

  testWidgets('the glow is part of its bubble: it stays inside the ring and '
      'a tap on it opens the need', (tester) async {
    for (final need in [CareNeed.food, CareNeed.toilet]) {
      final tapped = await pump(tester, highlight: need);

      final ring = tester.getRect(find.byType(CareRing));
      final glow = circle(tester, need).inflate(AppConstants.careNeedGlow);
      expect(ring.expandToInclude(glow), ring, reason: '$need');
      expect(
        bubble(tester, need).expandToInclude(glow),
        bubble(tester, need),
        reason: '$need',
      );

      await tester.tapAt(Offset(glow.center.dx, glow.top + 1));
      expect(tapped, [need]);
    }
  });

  testWidgets('tapping the Buddy opens no need', (tester) async {
    final tapped = await pump(tester);

    await tester.tap(find.byKey(const Key('buddy_double')));
    expect(tapped, isEmpty);
    expect(buddyTapsLog.length, 1);
  });

  testWidgets("behindBuddy: bottom-centred in the Buddy's square, under him", (
    tester,
  ) async {
    const behindKey = Key('behind');
    await pump(
      tester,
      behindBuddy: const SizedBox(key: behindKey, width: 50, height: 80),
    );

    final square = tester.getRect(find.byKey(CareRing.buddyKey));
    final behind = tester.getRect(find.byKey(behindKey));
    expect(behind.size, const Size(50, 80));
    expect(behind.bottom, moreOrLessEquals(square.bottom));
    expect(behind.center.dx, moreOrLessEquals(square.center.dx));
    // Painted first, so under him.
    expect(
      find
          .descendant(
            of: find.byType(CareRing),
            matching: find.byWidgetPredicate(
              (w) => w.key == behindKey || w.key == const Key('buddy_double'),
            ),
          )
          .evaluate()
          .map((e) => e.widget.key),
      [behindKey, const Key('buddy_double')],
    );

    // Never a tap target: a tap on it lands on the Buddy.
    await tester.tapAt(behind.center);
    expect(buddyTapsLog, hasLength(1));
  });

  testWidgets('behindBuddy larger than his square: at its own size, clipped '
      'to the ring between the bubbles; the bubbles still open', (
    tester,
  ) async {
    const behindKey = Key('behind');
    final tapped = await pump(
      tester,
      behindBuddy: const SizedBox(key: behindKey, width: 600, height: 600),
    );

    final square = tester.getRect(find.byKey(CareRing.buddyKey));
    final behind = tester.getRect(find.byKey(behindKey));
    expect(behind.size, const Size(600, 600));
    expect(behind.bottom, moreOrLessEquals(square.bottom));
    expect(behind.center.dx, moreOrLessEquals(square.center.dx));

    final clip = tester
        .getRect(
          find
              .ancestor(
                of: find.byKey(behindKey),
                matching: find.byType(ClipRect),
              )
              .first,
        )
        .deflate(0.01);
    final ring = tester.getRect(find.byType(CareRing));
    // The ring's middle, between the bubbles.
    expect(
      clip.width,
      moreOrLessEquals(CareRing.middleWidthFor(ring.width) - 0.02),
    );
    expect(ring.inflate(0.01).contains(clip.topLeft), isTrue);
    expect(ring.inflate(0.01).contains(clip.bottomRight), isTrue);
    expect(clip.contains(square.center), isTrue);
    for (final need in CareNeed.values) {
      expect(clip.overlaps(bubble(tester, need)), isFalse, reason: '$need');
      await tester.tap(find.byKey(CareRing.needKey(need)));
    }
    expect(tapped, CareNeed.values);
    expect(buddyTapsLog, isEmpty);
  });

  testWidgets("behindBuddy fades out toward the bubbles and the ring's top, so "
      'it shows no edge where it is cut off', (tester) async {
    const behindKey = Key('behind');
    await pump(
      tester,
      behindBuddy: const ColoredBox(
        key: behindKey,
        color: AppTheme.foreground,
        child: SizedBox(width: 600, height: 600),
      ),
    );

    final clip = tester.getRect(
      find
          .ancestor(of: find.byKey(behindKey), matching: find.byType(ClipRect))
          .first,
    );
    final ring = tester.getRect(find.byType(CareRing));
    expect(clip.top, moreOrLessEquals(ring.top));
    final square = tester.getRect(find.byKey(CareRing.buddyKey));
    final bytes = (await tester.runAsync(() async {
      final image = await captureImage(find.byType(CareRing).evaluate().single);
      return image.toByteData();
    }))!;
    final width = tester.view.physicalSize.width.round();

    /// How much of the behind shows at ([x], [y]): 0 none, 1 all of it.
    double shown(double x, double y) {
      final i = (y.round() * width + x.round()) * 4;
      const fg = AppTheme.foreground;
      final bg = AppTheme.background.r * 255;
      return (bg - bytes.getUint8(i)) / (bg - fg.r * 255);
    }

    const fade = AppConstants.careRingBehindFade;
    // A row inside the ring, above his square and below the top's fade.
    final y = square.top - 2;
    expect(y, greaterThan(clip.top + fade + 1));
    expect(shown(clip.center.dx, y), moreOrLessEquals(1, epsilon: 0.02));
    for (final edge in [clip.left + 0.5, clip.right - 0.5]) {
      expect(shown(edge, y), lessThan(0.1), reason: 'at $edge');
    }
    for (final x in [clip.left + fade + 1, clip.right - fade - 1]) {
      expect(shown(x, y), moreOrLessEquals(1, epsilon: 0.02), reason: 'at $x');
    }
    expect(shown(clip.left + fade / 2, y), inInclusiveRange(0.3, 0.7));

    // Its middle, at the ring's top.
    final x = clip.center.dx;
    expect(shown(x, clip.top + 0.5), lessThan(0.1));
    expect(shown(x, clip.top + fade / 2), inInclusiveRange(0.3, 0.7));
    expect(shown(x, clip.top + fade + 1), moreOrLessEquals(1, epsilon: 0.02));
  });

  testWidgets('behindBuddy never takes a tap, even where the Buddy does not', (
    tester,
  ) async {
    var behindTaps = 0;
    const behindKey = Key('behind');
    final tapped = await pump(
      tester,
      buddy: const SizedBox.expand(),
      behindBuddy: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => behindTaps++,
        child: const SizedBox(key: behindKey, width: 50, height: 80),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byKey(behindKey)));
    expect(behindTaps, 0);
    expect(tapped, isEmpty);
  });

  /// The top of the Buddy's head in his [square].
  double headOf(Rect square) => square.top + BuddyLayout(square.size).origin.dy;

  testWidgets('overBuddy: on his head, over the bubbles, never a tap target', (
    tester,
  ) async {
    var overTaps = 0;
    const overKey = Key('over');
    final tapped = await pump(
      tester,
      // A tap target of its own (as the bubble is), which never gets one.
      overBuddy: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => overTaps++,
        child: const SizedBox(key: overKey, width: 300, height: 60),
      ),
    );

    final ring = tester.getRect(find.byType(CareRing));
    final square = tester.getRect(find.byKey(CareRing.buddyKey));
    final over = tester.getRect(find.byKey(overKey));
    expect(over.bottom, closeTo(headOf(square), 0.01));
    expect(over.center.dx, closeTo(ring.center.dx, 0.01));
    // Painted after the bubbles, so over them.
    expect(
      find
          .descendant(
            of: find.byType(CareRing),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key == overKey || w.key == CareRing.needKey(CareNeed.drink),
            ),
          )
          .evaluate()
          .map((e) => e.widget.key),
      [CareRing.needKey(CareNeed.drink), overKey],
    );

    // Never a tap target: a tap where it covers Essen opens Essen.
    final overlap = over.intersect(bubble(tester, CareNeed.food));
    expect(overlap.isEmpty, isFalse);
    await tester.tapAt(overlap.center);
    expect(overTaps, 0);
    expect(tapped, [CareNeed.food]);
  });

  testWidgets('a taller overBuddy is fitted into the room above the ring', (
    tester,
  ) async {
    const tallKey = Key('tall');
    await pump(
      tester,
      overBuddyRoom: 48,
      overBuddy: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(key: tallKey, width: 100, height: 1000),
      ),
    );

    final ring = tester.getRect(find.byType(CareRing));
    final square = tester.getRect(find.byKey(CareRing.buddyKey));
    final tall = tester.getRect(find.byKey(tallKey));
    expect(tall.top, greaterThanOrEqualTo(ring.top - 48 - 0.01));
    // All of the room: it rises over the ring by it.
    expect(tall.top, lessThanOrEqualTo(ring.top - 48 + 0.01));
    expect(tall.bottom, closeTo(headOf(square), 0.01));
  });

  testWidgets('the ring between the bubbles is no tap target', (tester) async {
    final tapped = await pump(tester);

    // The ring's top edge, between Essen and Trinken.
    final ring = tester.getRect(find.byType(CareRing));
    await tester.tapAt(ring.topCenter + const Offset(0, 4));
    expect(tapped, isEmpty);
    expect(buddyTapsLog, isEmpty);
  });

  testWidgets('bubbles are buttons that say when it was last', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, log: CareLog(lastMealAt: _t(13)));

    for (final need in CareNeed.values) {
      expect(
        tester.getSemantics(find.byKey(CareRing.needKey(need))),
        isSemantics(label: need.logLabel, isButton: true, hasTapAction: true),
        reason: '$need',
      );
    }
    String? value(CareNeed need) =>
        tester.getSemantics(find.byKey(CareRing.needKey(need))).value;
    expect(value(CareNeed.food), 'zuletzt vor 1 Std');
    expect(value(CareNeed.drink), 'noch nicht eingetragen');
    expect(value(CareNeed.toilet), 'heute noch nicht');
    handle.dispose();
  });

  testWidgets('a rebuild with the same levels does not animate; a change '
      'does', (tester) async {
    await pump(tester, log: CareLog(lastMealAt: _t(13)));
    expect(tester.hasRunningAnimations, isFalse);

    // The hero rebuilds the ring (on every Buddy status, …) with the same
    // log at the same minute.
    await pump(
      tester,
      log: CareLog(lastMealAt: _t(13)),
      settle: Duration.zero,
    );
    expect(tester.hasRunningAnimations, isFalse);

    await pump(
      tester,
      log: CareLog(lastMealAt: _t(13, 30)),
      settle: Duration.zero,
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(needMeterLevel(tester, CareNeed.food), _foodAt14(_t(13, 30)));
  });

  testWidgets('a later minute updates what a bubble says without moving a '
      'meter at the floor', (tester) async {
    final handle = tester.ensureSemantics();
    // Breakfast at 07:00: Essen at the floor from 12:00 on.
    final log = CareLog(lastMealAt: _t(7));
    String? value() =>
        tester.getSemantics(find.byKey(CareRing.needKey(CareNeed.food))).value;
    await pump(tester, log: log, now: _t(13));
    expect(value(), 'zuletzt vor 6 Std');

    await pump(tester, log: log, now: _t(14), settle: Duration.zero);
    expect(value(), 'zuletzt vor 7 Std');
    expect(needMeterLevel(tester, CareNeed.food), AppConstants.careMeterFloor);
    expect(tester.hasRunningAnimations, isFalse);
    handle.dispose();
  });

  testWidgets('the meter just logged still fills while its glow moves on', (
    tester,
  ) async {
    await pump(tester, highlight: CareNeed.drink);
    expect(needMeterLevel(tester, CareNeed.drink), AppConstants.careMeterFloor);

    // A drink logged: Trinken is full, the glow goes elsewhere.
    await pump(
      tester,
      log: CareLog(lastDrinkAt: _t(14)),
      highlight: CareNeed.food,
      settle: Duration.zero,
    );
    expect(tester.hasRunningAnimations, isTrue);
    expect(needMeterLevel(tester, CareNeed.drink), lessThan(1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(needMeterLevel(tester, CareNeed.drink), 1);
  });

  testWidgets('reduced motion: a new level shows at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, log: CareLog(lastMealAt: _t(13)));
    expect(needMeterLevel(tester, CareNeed.food), _foodAt14(_t(13)));

    await pump(
      tester,
      log: CareLog(lastMealAt: _t(13, 30)),
      settle: Duration.zero,
    );
    expect(needMeterLevel(tester, CareNeed.food), _foodAt14(_t(13, 30)));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the four-quarter ring is gone: all it paints are the meters', (
    tester,
  ) async {
    await pump(tester, log: CareLog(lastMealAt: _t(13)));

    final paints = find.descendant(
      of: find.byType(CareRing),
      matching: find.byType(CustomPaint),
    );
    expect(paints, findsWidgets);
    for (final paint in paints.evaluate()) {
      expect(
        find.ancestor(
          of: find.byElementPredicate((e) => e == paint),
          matching: find.byType(NeedMeter),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the bubbles sit in the four corners', (tester) async {
    await pump(tester);

    final ring = tester.getRect(find.byType(CareRing));
    void at(Offset corner, Offset of) =>
        expect(corner, offsetMoreOrLessEquals(of, epsilon: 1e-6));
    at(bubble(tester, CareNeed.food).topLeft, ring.topLeft);
    at(bubble(tester, CareNeed.drink).topRight, ring.topRight);
    at(bubble(tester, CareNeed.toilet).bottomLeft, ring.bottomLeft);
    at(bubble(tester, CareNeed.gutFeeling).bottomRight, ring.bottomRight);
  });

  group('the next need\'s glow', () {
    setUp(() => CareRing.pulseEnabled = true);
    tearDown(() => CareRing.pulseEnabled = false);

    /// The spread of [need]'s glow, or null when it has none.
    double? glow(WidgetTester tester, CareNeed need) {
      final shadows = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(CareRing.needKey(need)),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .expand((d) => d.boxShadow ?? const <BoxShadow>[])
          .where((s) => s.color == AppTheme.careGlow);
      return shadows.isEmpty ? null : shadows.single.spreadRadius;
    }

    testWidgets('only the highlighted need glows, pulsing on its own clock', (
      tester,
    ) async {
      await pump(tester, highlight: CareNeed.food);

      for (final need in [
        CareNeed.drink,
        CareNeed.gutFeeling,
        CareNeed.toilet,
      ]) {
        expect(glow(tester, need), isNull, reason: '$need');
      }
      final before = glow(tester, CareNeed.food)!;
      await tester.pump(const Duration(milliseconds: 350));
      final after = glow(tester, CareNeed.food)!;
      expect(after, isNot(before));
      for (final spread in [before, after]) {
        expect(spread, greaterThanOrEqualTo(AppConstants.careNeedGlow * 0.6));
        expect(spread, lessThanOrEqualTo(AppConstants.careNeedGlow));
      }
    });

    testWidgets('the glow is a circle around the meter', (tester) async {
      await pump(tester, highlight: CareNeed.drink);

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(CareRing.needKey(CareNeed.drink)),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                ((w.decoration as BoxDecoration).boxShadow ?? []).any(
                  (s) => s.color == AppTheme.careGlow,
                ),
          ),
        ),
      );
      expect((box.decoration as BoxDecoration).shape, BoxShape.circle);
      expect(
        tester.getRect(
          find.ancestor(
            of: meterOf(CareNeed.drink),
            matching: find.byWidget(box),
          ),
        ),
        circle(tester, CareNeed.drink),
      );
    });

    testWidgets('the pulse repaints the glow, not the meter', (tester) async {
      await pump(tester, highlight: CareNeed.drink);

      final glowBox = tester.renderObject(
        find.descendant(
          of: find.byKey(CareRing.needKey(CareNeed.drink)),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                ((w.decoration as BoxDecoration?)?.boxShadow ?? []).isNotEmpty,
          ),
        ),
      );
      // The first layer above the meter is its own, inside the glow.
      RenderObject? layer = tester.renderObject(meterOf(CareNeed.drink));
      while (!layer!.isRepaintBoundary) {
        layer = layer.parent;
      }
      var above = layer.parent;
      while (above != null && !identical(above, glowBox)) {
        above = above.parent;
      }
      expect(above, same(glowBox));
    });

    testWidgets('reduced motion: a full glow that holds still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, highlight: CareNeed.drink);

      expect(glow(tester, CareNeed.drink), AppConstants.careNeedGlow);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  /// The text scale each need's label is drawn at.
  List<double> labelScales(WidgetTester tester) => [
    for (final need in CareNeed.values)
      tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(CareRing.needKey(need)),
              matching: find.text(need.label),
            ),
          )
          .textScaler
          .scale(1),
  ];

  for (final (name, size, scale) in [
    ('iPhone 17 Pro', const Size(393, 852), 1.3),
    ('small phone', const Size(375, 667), 1.3),
    ('small phone', const Size(375, 667), 2.0),
  ]) {
    testWidgets('$name at text scale $scale: no overflow, bubbles apart, the '
        'labels at one size', (tester) async {
      await pump(
        tester,
        log: CareLog(
          lastMealAt: _t(13),
          lastDrinkAt: _t(12, 30),
          lastGutFeelingAt: _t(8),
        ),
        size: size,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      // Klo's second line at its longest.
      expect(find.text('heute noch nicht'), findsOneWidget);
      for (final (top, bottom) in [
        (CareNeed.food, CareNeed.toilet),
        (CareNeed.drink, CareNeed.gutFeeling),
      ]) {
        expect(
          bubble(tester, bottom).top,
          greaterThanOrEqualTo(bubble(tester, top).bottom),
          reason: '$top over $bottom',
        );
      }
      final scales = labelScales(tester);
      expect(scales.toSet(), hasLength(1));
      expect(scales.first, lessThanOrEqualTo(scale));
      for (final need in CareNeed.values) {
        expect(
          tester.getSize(find.text(need.label)).width,
          lessThanOrEqualTo(AppConstants.careNeedWidth),
          reason: '$need',
        );
      }
      // The ring grows instead; the Buddy keeps his height.
      final ring = tester.getRect(find.byType(CareRing));
      expect(
        ring.height,
        greaterThanOrEqualTo(
          CareRing.diameterFor(size.width - 32, size.height),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('buddy_double'))).height,
        moreOrLessEquals(
          CareRing.diameterFor(size.width - 32, size.height) *
              AppConstants.careRingBuddyFactor,
        ),
      );
    });
  }
}
