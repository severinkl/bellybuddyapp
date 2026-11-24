// ignore_for_file: invalid_use_of_internal_member
import 'dart:ui' show SemanticsFlag;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:belly_buddy/screens/trackers/toilet/toilet_tracker_screen.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('ToiletTrackerScreen', () {
    testWidgets('renders screen title', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Am Klo 💩 gewesen?'), findsOneWidget);
    });

    testWidgets('renders Konsistenz? label', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Konsistenz?'), findsOneWidget);
    });

    testWidgets('VoiceOver reads the slider as the consistency, not in '
        'percent', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      final node = find.semantics
          .byFlag(SemanticsFlag.isSlider)
          .evaluate()
          .single;
      expect(node.label, 'Konsistenz');
      expect(node.value, isNot(contains('%')));
      expect(node.value, contains('von 5'));
      semantics.dispose();
    });

    testWidgets('renders slider labels', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('sehr hart'), findsOneWidget);
      expect(find.text('flüssig'), findsOneWidget);
    });

    testWidgets('renders speichern button', (tester) async {
      await tester.pumpWithProviders(
        const ToiletTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('successful save emits a Buddy event and shows the reaction', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ToiletTrackerScreen()),
        ),
      );

      await tester.tap(find.text('Speichern'));
      await tester.pump();
      // The Buddy animates forever: pump past the overlay intro only.
      await tester.pump(const Duration(milliseconds: 700));

      final event = container.read(buddyEventsProvider);
      expect(event?.kind, EntryKind.toilet);
      // Default stool type 3 ("normal").
      expect(event?.sentiment, LogSentiment.good);
      expect(find.text('Klo-Eintrag gespeichert!'), findsOneWidget);
      final view = tester.widget<BuddyReactionView>(
        find.byType(BuddyReactionView),
      );
      expect(view.kind, EntryKind.toilet);
      expect(view.sentiment, LogSentiment.good);
      expect(find.byType(MascotImage), findsNothing);
      expect(
        tester.widget<BbSuccessOverlay>(find.byType(BbSuccessOverlay)).calm,
        isFalse,
      );
    });

    testWidgets('a hard one (sehr hart) gets the calm success screen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer.test(overrides: _overrides());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ToiletTrackerScreen()),
        ),
      );

      // The slider's far left: 1, „sehr hart".
      await tester.tapAt(
        tester.getTopLeft(find.byType(Slider)) + const Offset(24, 24),
      );
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(container.read(buddyEventsProvider)?.sentiment, LogSentiment.bad);
      expect(find.text('Klo-Eintrag gespeichert.'), findsOneWidget);
      expect(
        tester.widget<BbSuccessOverlay>(find.byType(BbSuccessOverlay)).calm,
        isTrue,
      );
    });
  });
}
