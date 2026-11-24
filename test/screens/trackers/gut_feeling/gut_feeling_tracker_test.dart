// ignore_for_file: invalid_use_of_internal_member
import 'dart:ui' show SemanticsFlag;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/providers/care_log_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/widgets/buddy/log_success_hero.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';
import 'package:belly_buddy/config/constants.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides([FakeEntryRepository? entries]) => [
  entryRepositoryProvider.overrideWithValue(entries ?? FakeEntryRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

class _LockedInsights extends InsightsNotifier {
  @override
  Future<Insights> build() async => const Insights(
    progress: InsightProgress(activeDays: 2, gutFeelingEntries: 1),
    calendar: [],
    goodDays: DayColumn(days: 0),
    hardDays: DayColumn(days: 0),
    noticed: [],
    pick: NothingYetPick(),
  );
}

void main() {
  group('GutFeelingTrackerScreen', () {
    testWidgets('renders screen appBar title', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      // Use pump with duration to let entry animations start
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Wie geht es dir?'), findsOneWidget);
    });

    testWidgets('renders two tab options', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // MoodTabSelector has "Bauchgefühl" and "Stimmung" tabs
      expect(find.text('Bauchgefühl'), findsOneWidget);
      expect(find.text('Stimmung'), findsOneWidget);
    });

    testWidgets('the symptom sliders start at „gar nicht"', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('gar nicht'), findsWidgets);
      expect(find.text('garnicht'), findsNothing);
    });

    testWidgets('VoiceOver reads each symptom slider by its name and as '
        '„N von 5", not in percent', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      // Past the entry fade-in (hidden from screen readers until shown).
      await tester.pump(const Duration(seconds: 1));

      final sliders = find.semantics
          .byFlag(SemanticsFlag.isSlider)
          .evaluate()
          .toList();
      expect(sliders, hasLength(4));
      for (var i = 0; i < 4; i++) {
        final node = sliders[i];
        expect(node.label, AppConstants.gutFeelingSymptoms[i]);
        expect(node.value, '1 von 5');
        expect(node.increasedValue, '2 von 5');
        expect(node.value, isNot(contains('%')));
      }
      semantics.dispose();
    });

    testWidgets('renders weiter button on first tab', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Weiter'), findsOneWidget);
    });

    testWidgets('renders PageView with two pages', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('successful save emits a Buddy event and shows the reaction', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GutFeelingTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Weiter'));
      // Page slide (350 ms): start, finish, rebuild with the new label.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      // The Buddy animates forever: pump past the overlay intro only.
      await tester.pump(const Duration(milliseconds: 700));

      final event = container.read(buddyEventsProvider);
      expect(event?.kind, EntryKind.gutFeeling);
      // All sliders at their default 1 → spiGut → good.
      expect(event?.sentiment, LogSentiment.good);
      expect(find.text('Eintrag gespeichert!'), findsOneWidget);
      final view = tester.widget<BuddyReactionView>(
        find.byType(BuddyReactionView),
      );
      expect(view.kind, EntryKind.gutFeeling);
      expect(view.sentiment, LogSentiment.good);
      expect(find.byType(MascotImage), findsNothing);
    });

    testWidgets('the Bauchgefühl page charges Bauchgefühl', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // A past day's entry is logged at 12:00; the clock reads 12:00 too.
      await tester.pumpWithProviders(
        GutFeelingTrackerScreen(initialDate: DateTime(2026, 11, 23)),
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 12),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final meter = tester.widget<ChargingMeter>(find.byType(ChargingMeter));
      expect(meter.need, CareNeed.gutFeeling);
      expect(meter.from, AppConstants.careMeterFloor);
      expect(meter.to, 1.0);
      expect(
        find.descendant(
          of: find.byType(LogSuccessHero),
          matching: find.byType(BuddyReactionView),
        ),
        findsOneWidget,
      );
    });

    Future<ProviderContainer> saveWithLine(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 12),
          ),
          insightsProvider.overrideWith(_LockedInsights.new),
          careLogProvider.overrideWithValue(const CareLog()),
          buddyProvider.overrideWith(
            () => FakeBuddyNotifier(() => buddyStatus(streak: 4)),
          ),
        ],
      );
      await container.read(insightsProvider.future);
      await container.read(buddyProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GutFeelingTrackerScreen(initialDate: DateTime(2026, 11, 23)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      return container;
    }

    testWidgets("the day's first Bauchgefühl, locked: the Buddy says how far "
        'it is', (tester) async {
      await saveWithLine(tester);

      const line = 'Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.';
      expect(find.text(line), findsOneWidget);
    });

    testWidgets('fits 375×667 at text scale 1.3 with the line and the ignite '
        'row', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      // Test-font glyphs overflow sideways; only the bottom matters here.
      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await saveWithLine(tester);
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(find.byKey(LogSuccessHero.igniteKey), findsOneWidget);
      expect(
        tester
            .widget<LogSuccessHero>(find.byType(LogSuccessHero))
            .moment
            .buddyLine,
        isNotNull,
      );
      expect(
        errors.where((e) => e.exceptionAsString().contains('bottom')),
        isEmpty,
      );
    });

    Future<ProviderContainer> pumpTracker(
      WidgetTester tester,
      FakeEntryRepository entries,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides(entries));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GutFeelingTrackerScreen()),
        ),
      );
      // Past the entry animation, so the mascots take taps.
      await tester.pump(const Duration(milliseconds: 700));
      return container;
    }

    Future<void> tapMascot(WidgetTester tester, String asset) async {
      final mascot = find.byWidgetPredicate(
        (w) => w is MascotImage && w.assetPath == asset,
      );
      await tester.ensureVisible(mascot);
      await tester.pump();
      await tester.tap(mascot);
      await tester.pump();
    }

    Future<void> goToStimmungAndSave(WidgetTester tester) async {
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('an untouched Stimmung tab saves no mood values', (
      tester,
    ) async {
      final entries = FakeEntryRepository();
      await pumpTracker(tester, entries);

      await goToStimmungAndSave(tester);

      final saved = entries.inserted.single;
      for (final key in ['stress', 'happiness', 'energy', 'focus']) {
        expect(saved[key], isNull, reason: key);
      }
      expect(saved['body_feel'], isNull);
      expect(saved['bloating'], 1);
    });

    testWidgets('a mood slider the user set is saved', (tester) async {
      final entries = FakeEntryRepository();
      await pumpTracker(tester, entries);
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      await tapMascot(tester, AppConstants.mascotStressed);
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final saved = entries.inserted.single;
      expect(saved['stress'], 5);
      expect(saved['happiness'], isNull);
    });

    testWidgets('Krämpfe 5 and Völlegefühl 5 make a hard day for the Buddy', (
      tester,
    ) async {
      final entries = FakeEntryRepository();
      final container = await pumpTracker(tester, entries);

      await tapMascot(tester, AppConstants.mascotCramp);
      await tapMascot(tester, AppConstants.mascotFullness);
      await goToStimmungAndSave(tester);

      expect(entries.inserted.single['cramps'], 5);
      expect(entries.inserted.single['fullness'], 5);
      final event = container.read(buddyEventsProvider);
      expect(event?.sentiment, LogSentiment.bad);
      final view = tester.widget<BuddyReactionView>(
        find.byType(BuddyReactionView),
      );
      expect(view.sentiment, LogSentiment.bad);
      // No celebration after a hard day: the calm success screen.
      final overlay = tester.widget<BbSuccessOverlay>(
        find.byType(BbSuccessOverlay),
      );
      expect(overlay.calm, isTrue);
      expect(overlay.message, isNot(contains('!')));
    });

    testWidgets('after a hard day the calm page lights no „Tag n", even on '
        "today's first entry", (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(
        overrides: [
          ..._overrides(),
          buddyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 23, 14),
          ),
          buddyProvider.overrideWith(
            () => FakeBuddyNotifier(() => buddyStatus(streak: 4)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(buddyProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GutFeelingTrackerScreen(initialDate: DateTime(2026, 11, 23)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      await tapMascot(tester, AppConstants.mascotCramp);
      await tapMascot(tester, AppConstants.mascotFullness);
      await goToStimmungAndSave(tester);

      expect(
        tester.widget<BbSuccessOverlay>(find.byType(BbSuccessOverlay)).calm,
        isTrue,
      );
      // Today's first entry: it does make day 5 …
      expect(
        tester
            .widget<LogSuccessHero>(find.byType(LogSuccessHero))
            .moment
            .ignitesDay,
        5,
      );
      // … but the calm page cheers no progress.
      expect(find.byKey(LogSuccessHero.igniteKey), findsNothing);
      expect(find.text('Tag 5'), findsNothing);
    });

    testWidgets('a good day gets the cheerful success screen', (tester) async {
      final entries = FakeEntryRepository();
      await pumpTracker(tester, entries);

      await goToStimmungAndSave(tester);

      final overlay = tester.widget<BbSuccessOverlay>(
        find.byType(BbSuccessOverlay),
      );
      expect(overlay.calm, isFalse);
    });

    testWidgets('on a phone, the Stimmung rows end above Speichern', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622); // iPhone 17
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpTracker(tester, FakeEntryRepository());

      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final button = find.ancestor(
        of: find.text('Speichern'),
        matching: find.byType(BbButton),
      );
      expect(button, findsOneWidget);
      final buttonTop = tester.getRect(button).top;
      expect(
        tester.getRect(find.byType(PageView)).bottom,
        lessThanOrEqualTo(buttonTop),
        reason: 'the content ends above the pinned button, not under it',
      );
      await tester.ensureVisible(find.text('unwohl'));
      await tester.pump();
      expect(tester.getRect(find.text('unwohl')).bottom, lessThan(buttonTop));
    });
  });
}
