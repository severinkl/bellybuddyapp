import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';

void main() {
  Future<List<CareNeed>> pump(
    WidgetTester tester, {
    DailyCare care = const DailyCare(),
    CareNeed? highlight,
    Size size = const Size(393, 852),
    double textScale = 1.0,
    Duration settle = const Duration(milliseconds: 400),
  }) async {
    final tapped = <CareNeed>[];
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
                  care: care,
                  diameter: CareRing.diameterFor(width, size.height),
                  highlight: highlight,
                  onNeed: tapped.add,
                  buddy: const ColoredBox(color: AppTheme.buddyBody),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(settle);
    return tapped;
  }

  test('diameter: at most 260, a share of width and height, at least 170', () {
    expect(CareRing.diameterFor(361, 852), closeTo(255.6, 0.01));
    expect(CareRing.diameterFor(1000, 2000), 260);
    expect(CareRing.diameterFor(343, 667), closeTo(200.1, 0.01));
    expect(CareRing.diameterFor(200, 400), 170);
  });

  testWidgets('shows each need with its count', (tester) async {
    await pump(
      tester,
      care: const DailyCare(meals: 2, glasses: 3, gutFeelings: 1, toilets: 1),
    );

    expect(find.text('🍽 2/3'), findsOneWidget);
    expect(find.text('💧 3/6'), findsOneWidget);
    expect(find.text('🙂 ✓'), findsOneWidget);
    expect(find.text('🧻 1×'), findsOneWidget);
    expect(find.text('Essen'), findsOneWidget);
    expect(find.text('Trinken'), findsOneWidget);
    expect(find.text('Bauchgefühl'), findsOneWidget);
    expect(find.text('Klo'), findsOneWidget);
  });

  testWidgets('nothing logged: open marks for Bauchgefühl and Klo', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('🙂 –'), findsOneWidget);
    expect(find.text('🧻 –'), findsOneWidget);
  });

  testWidgets('each bubble reports its need', (tester) async {
    final tapped = await pump(tester);

    for (final need in CareNeed.values) {
      await tester.tap(find.byKey(CareRing.needKey(need)));
    }
    expect(tapped, CareNeed.values);
  });

  testWidgets('bubbles are buttons with a spoken count', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, care: const DailyCare(meals: 1));

    expect(
      tester.getSemantics(find.byKey(CareRing.needKey(CareNeed.food))),
      matchesSemantics(
        label: 'Essen: 1 von 3 Mahlzeiten',
        hint: 'Mahlzeit eintragen',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a rebuild with the same progress does not animate the ring '
      'again; a change does', (tester) async {
    await pump(tester, care: const DailyCare(meals: 1, glasses: 2));
    expect(tester.hasRunningAnimations, isFalse);

    // The hero rebuilds the ring (every minute, on every Buddy status)
    // with the same care.
    await pump(
      tester,
      care: const DailyCare(meals: 1, glasses: 2),
      settle: Duration.zero,
    );
    expect(tester.hasRunningAnimations, isFalse);

    await pump(
      tester,
      care: const DailyCare(meals: 2, glasses: 2),
      settle: Duration.zero,
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the bubbles sit in the four corners', (tester) async {
    await pump(tester);

    final ring = tester.getRect(find.byType(CareRing));
    Rect at(CareNeed n) => tester.getRect(find.byKey(CareRing.needKey(n)));
    expect(at(CareNeed.food).topLeft, ring.topLeft);
    expect(at(CareNeed.drink).topRight, ring.topRight);
    expect(at(CareNeed.toilet).bottomLeft, ring.bottomLeft);
    expect(at(CareNeed.gutFeeling).bottomRight, ring.bottomRight);
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

  for (final (name, size) in [
    ('iPhone 17 Pro', const Size(393, 852)),
    ('small phone', const Size(375, 667)),
  ]) {
    testWidgets('$name at text scale 1.3: no overflow, bubbles apart', (
      tester,
    ) async {
      await pump(
        tester,
        care: const DailyCare(meals: 2, glasses: 3, toilets: 12),
        size: size,
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      Rect at(CareNeed n) => tester.getRect(find.byKey(CareRing.needKey(n)));
      expect(at(CareNeed.food).overlaps(at(CareNeed.toilet)), isFalse);
      expect(at(CareNeed.drink).overlaps(at(CareNeed.gutFeeling)), isFalse);
    });
  }
}
