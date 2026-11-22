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
import 'package:belly_buddy/widgets/common/mascot_image.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
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

    testWidgets('renders weiter button on first tab', (tester) async {
      await tester.pumpWithProviders(
        const GutFeelingTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('weiter'), findsOneWidget);
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

      await tester.tap(find.text('weiter'));
      // Page slide (350 ms): start, finish, rebuild with the new label.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('speichern'));
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
  });
}
