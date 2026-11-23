// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';
import 'package:belly_buddy/config/constants.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides([FakeEntryRepository? entries]) => [
  entryRepositoryProvider.overrideWithValue(entries ?? FakeEntryRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

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
