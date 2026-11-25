// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/buddy/log_moment.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/widgets/buddy/log_success_hero.dart';
import 'package:belly_buddy/widgets/buddy/need_icon.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/layout_checks.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  currentUserIdProvider.overrideWithValue('u1'),
];

LogSuccessHero _hero(LogMoment moment) => LogSuccessHero(moment: moment);

/// A drink, today's first entry: it ignites day 5.
const _ignites = LogMoment(
  kind: EntryKind.drink,
  from: 0.4,
  to: 1.0,
  ignitesDay: 5,
);

/// A meal, today's first entry, for the short slots.
const _mealIgnites = LogMoment(
  kind: EntryKind.meal,
  from: 0.2,
  to: 1.0,
  ignitesDay: 1,
);

Future<void> _pump(WidgetTester tester, Widget hero) =>
    tester.pumpWithProviders(
      Scaffold(body: Center(child: hero)),
      overrides: _overrides(),
    );

/// The level the charging circle shows.
double? _level(WidgetTester tester) => tester
    .widget<NeedMeter>(
      find.descendant(
        of: find.byType(ChargingMeter),
        matching: find.byType(NeedMeter),
      ),
    )
    .level;

FlamePainter _flamePainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(StreakFlame),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as FlamePainter;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LogSuccessHero', () {
    testWidgets('the circle charges from the old level to the new in about '
        '1.2 s', (tester) async {
      await _pump(
        tester,
        _hero(const LogMoment(kind: EntryKind.drink, from: 0.4, to: 1.0)),
      );

      expect(_level(tester), closeTo(0.4, 0.005));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_level(tester), allOf(greaterThan(0.4), lessThan(1.0)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_level(tester), 1.0);
      expect(
        tester.widget<NeedMeter>(find.byType(NeedMeter)).need,
        CareNeed.drink,
      );
      final icon = tester.widget<NeedIcon>(
        find.descendant(
          of: find.byType(ChargingMeter),
          matching: find.byType(NeedIcon),
        ),
      );
      expect(icon.need, CareNeed.drink);
      expect(
        icon.size,
        tester.getSize(find.byType(NeedMeter)).width *
            AppConstants.careMeterIconShare,
      );
    });

    group('reduced motion', () {
      setUp(() {
        TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
      });
      tearDown(
        TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .clearAccessibilityFeaturesTestValue,
      );

      testWidgets('the new level at once', (tester) async {
        await _pump(
          tester,
          _hero(const LogMoment(kind: EntryKind.drink, from: 0.4, to: 1.0)),
        );
        await tester.pump();

        expect(_level(tester), 1.0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('the flame is lit at once, without the burst', (
        tester,
      ) async {
        await _pump(tester, _hero(_ignites));
        await tester.pump();

        expect(find.byKey(LogSuccessHero.igniteKey), findsOneWidget);
        final flame = _flamePainter(tester);
        expect(flame.look, FlameLook.lit);
        expect(flame.burst, isNull);
        expect(_level(tester), 1.0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    });

    testWidgets('Klo: no circle', (tester) async {
      await _pump(tester, _hero(const LogMoment(kind: EntryKind.toilet)));

      expect(find.byType(ChargingMeter), findsNothing);
      expect(find.byType(NeedMeter), findsNothing);
      expect(find.byType(BuddyReactionView), findsOneWidget);
    });

    testWidgets("today's first entry: the flame ignites next to „Tag 5\"", (
      tester,
    ) async {
      await _pump(tester, _hero(_ignites));

      final row = find.byKey(LogSuccessHero.igniteKey);
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Tag 5')),
        findsOneWidget,
      );
      final flame = tester.widget<StreakFlame>(
        find.descendant(of: row, matching: find.byType(StreakFlame)),
      );
      expect(flame.lit, isTrue);
      expect(flame.streak, 5);
      expect(flame.igniteOnMount, isTrue);
    });

    testWidgets('otherwise no flame', (tester) async {
      await _pump(
        tester,
        _hero(const LogMoment(kind: EntryKind.drink, from: 0.4, to: 1.0)),
      );

      expect(find.byKey(LogSuccessHero.igniteKey), findsNothing);
      expect(find.byType(StreakFlame), findsNothing);
    });

    testWidgets('the calm page after a hard moment cheers no „Tag n"', (
      tester,
    ) async {
      await _pump(
        tester,
        _hero(
          const LogMoment(
            kind: EntryKind.toilet,
            sentiment: LogSentiment.bad,
            ignitesDay: 5,
          ),
        ),
      );

      expect(find.byKey(LogSuccessHero.igniteKey), findsNothing);
      expect(find.byType(StreakFlame), findsNothing);
      expect(find.text('Tag 5'), findsNothing);
      expect(find.byType(BuddyReactionView), findsOneWidget);
    });

    testWidgets('a tall slot: the circle above „Tag n"', (tester) async {
      await _pump(tester, SizedBox(height: 400, child: _hero(_mealIgnites)));
      await tester.pump(const Duration(milliseconds: 1300));

      final meter = tester.getRect(find.byType(ChargingMeter));
      final ignite = tester.getRect(find.byKey(LogSuccessHero.igniteKey));
      expect(meter.height, AppConstants.careChargeSize);
      expect(ignite.top, greaterThanOrEqualTo(meter.bottom));
    });

    testWidgets('a short slot: the circle beside „Tag n", a share of the slot, '
        'nothing scaled', (tester) async {
      await _pump(tester, SizedBox(height: 260, child: _hero(_mealIgnites)));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(tester.takeException(), isNull);
      final meter = tester.getRect(find.byType(ChargingMeter));
      final ignite = tester.getRect(find.byKey(LogSuccessHero.igniteKey));
      expect(ignite.left, greaterThanOrEqualTo(meter.right));
      expect(
        meter.height,
        moreOrLessEquals(260 * AppConstants.careChargeHeightShare),
      );
      expect(
        tester.getRect(find.byType(LogSuccessHero)).height,
        lessThanOrEqualTo(260),
      );
      expect(drawnScale(tester.element(find.text('Tag 1'))), 1);
      expect(
        tester.getRect(find.byType(AnimatedBuddy)).height,
        greaterThanOrEqualTo(minBuddyHeight),
      );
    });

    testWidgets('a slot too short for it all: the bubble yields, the Buddy '
        'keeps his body', (tester) async {
      await _pump(tester, SizedBox(height: 100, child: _hero(_mealIgnites)));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(tester.takeException(), isNull);
      final slot = tester.getRect(find.byType(LogSuccessHero));
      expect(slot.height, lessThanOrEqualTo(100));
      expect(find.byType(ChargingMeter), findsOneWidget);
      expect(drawnScale(tester.element(find.text('Tag 1'))), 1);
      final buddy = tester.getRect(find.byType(AnimatedBuddy));
      expect(buddy.height, greaterThanOrEqualTo(minBuddyHeight));
      expect(buddy.bottom, lessThanOrEqualTo(slot.bottom + 0.01));
    });
  });
}
