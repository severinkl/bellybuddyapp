import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/screens/dashboard/widgets/home_flame.dart';
import 'package:belly_buddy/screens/dashboard/widgets/insight_card.dart';
import 'package:belly_buddy/screens/trackers/drink/drink_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/toilet/toilet_tracker_screen.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/buddy/log_success_hero.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';
import 'package:belly_buddy/widgets/buddy/streak_badge.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';
import '../test/helpers/widget_tester_helpers.dart';
import 'helpers/test_app.dart';
import 'helpers/welcome_driver.dart' show pumpUntilFound;

/// A day without entries. The fake answers every day with it, also after a
/// log, so these flows check the success pages and the Buddy, not Home's
/// meters after the log.
const _emptyDay = EntryQueryResult(
  meals: [],
  toiletEntries: [],
  gutFeelings: [],
  drinks: [],
);

const _tapToContinue = 'Tippen zum Fortfahren';

/// [text] inside the streak badge on Home.
Finder _badgeText(String text) =>
    find.descendant(of: find.byType(StreakBadge), matching: find.text(text));

/// How Home's streak flame (behind the Buddy) shows.
FlameLook _homeFlame(WidgetTester tester) => tester
    .widget<StreakFlame>(
      find.descendant(
        of: find.byType(HomeFlame),
        matching: find.byType(StreakFlame),
      ),
    )
    .look;

/// Waits for the success page's hero after a save.
Future<void> _pumpUntilSuccess(WidgetTester tester) =>
    pumpUntilFound(tester, find.byType(LogSuccessHero));

/// Taps the success page's hint and lets Home settle.
Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text(_tapToContinue));
  await tester.pumpAndSettle();
  expect(find.byType(DashboardScreen), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The notification opt-in modal, not under test here, marked as shown;
  // the journey is decided once per user and stored, so each flow starts
  // undecided.
  setUp(() async {
    await setNotificationModalShown();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${AppConstants.keyInsightJourneyPrefix}$testUserId');
  });

  testWidgets('meter and charge: a drink from its bubble charges Trinken '
      'to full, and a tap leads back Home', (tester) async {
    // Today empty; Home's clock is the real one.
    await tester.pumpWidget(
      buildTestApp(entryRepo: FakeEntryRepository()..seedResult(_emptyDay)),
    );
    await tester.pumpAndSettle();

    await tester.tapVisible(find.byKey(CareRing.needKey(CareNeed.drink)));
    expect(find.byType(DrinkTrackerScreen), findsOneWidget);
    await tester.tapVisible(find.text('Wasser'));
    await tester.tapVisible(find.text('250 ml'));
    await tester.tap(find.text('Speichern'));

    final meter = find.byType(ChargingMeter);
    await pumpUntilFound(tester, meter);
    expect(tester.widget<ChargingMeter>(meter).need, CareNeed.drink);
    await pumpPastCharge(tester);
    final level = tester
        .widget<NeedMeter>(
          find.descendant(of: meter, matching: find.byType(NeedMeter)),
        )
        .level;
    // Full: the drink filled it up. A real clock under load may stop the
    // charge a hair short of 1.0 (0.9999984 seen).
    expect(level, closeTo(1.0, 1e-3));
    expect(find.text(_tapToContinue), findsOneWidget);

    await _continue(tester);
    expect(find.byType(DrinkTrackerScreen), findsNothing);
  });

  testWidgets("flame: the ember on a 3-day streak, today's Klo ignites "
      'Tag 4, and Home shows it lit', (tester) async {
    final today = startOfDay(DateTime.now());
    final entryRepo = FakeEntryRepository(countInsertsAsActivity: true)
      ..seedResult(_emptyDay)
      ..seedActivityDays({for (var i = 1; i <= 3; i++) addDays(today, -i)});
    await tester.pumpWidget(buildTestApp(entryRepo: entryRepo));
    await tester.pumpAndSettle();

    expect(_badgeText('3'), findsOneWidget);
    expect(_homeFlame(tester), FlameLook.ember);

    await tester.tapVisible(find.byKey(CareRing.needKey(CareNeed.toilet)));
    expect(find.byType(ToiletTrackerScreen), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await _pumpUntilSuccess(tester);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(LogSuccessHero.igniteKey),
        matching: find.text('Tag 4'),
      ),
      findsOneWidget,
    );

    await _continue(tester);
    await pumpUntilFound(tester, _badgeText('4'));
    await tester.pumpAndSettle();
    expect(_homeFlame(tester), FlameLook.lit);
  });

  testWidgets("journey and feedback: the card counts the days, and the day's "
      'first Bauchgefühl hears how far the first patterns are', (tester) async {
    final entryRepo = FakeEntryRepository()
      ..seedResult(_emptyDay)
      // 2 days with entries, none today, 1 Bauchgefühl.
      ..insightSource = insightSourceFor(
        activeDays: 2,
        gutFeelings: 1,
        now: DateTime.now(),
      );
    await tester.pumpWidget(buildTestApp(entryRepo: entryRepo));
    await tester.pumpAndSettle();

    final card = find.byKey(InsightCard.cardKey);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    for (final counter in ['2 von 7 Tagen', 'Bauchgefühl 1 von 3']) {
      expect(
        find.descendant(of: card, matching: find.text(counter)),
        findsOneWidget,
        reason: counter,
      );
    }

    await tester.tapVisible(find.byKey(CareRing.needKey(CareNeed.gutFeeling)));
    expect(find.byType(GutFeelingTrackerScreen), findsOneWidget);
    // Every slider at its default: a good Bauchgefühl.
    await tester.tapVisible(find.text('Weiter'));
    await tester.tap(find.text('Speichern'));
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(LogSuccessHero),
        matching: find.text(
          'Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.',
        ),
      ),
    );
  });
}
