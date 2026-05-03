// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/trackers/drink/drink_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_search.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/drink_tracker_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides({FakeDrinkRepository? drinkRepo}) => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  drinkRepositoryProvider.overrideWithValue(drinkRepo ?? FakeDrinkRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('DrinkTrackerScreen', () {
    testWidgets('renders screen title', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      // Use pump with duration to let async loading complete
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Was hast du getrunken? 💧'), findsOneWidget);
    });

    testWidgets('renders Heute label after loading', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Heute: '), findsOneWidget);
    });

    testWidgets('renders speichern button', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('speichern'), findsOneWidget);
    });

    testWidgets('renders quick drink grid after loading', (tester) async {
      await tester.pumpWithProviders(
        const DrinkTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // FakeDrinkRepository seeds with 'Wasser' drink
      expect(find.text('Wasser'), findsOneWidget);
    });

    testWidgets('initialDate seeds the drink-tracker trackedAt verbatim '
        '(no buildTrackedAt — full timestamp through)', (tester) async {
      final initial = DateTime(2026, 5, 1, 12, 30);
      // Use UncontrolledProviderScope so we can read provider state after
      // the post-frame callback fires.
      final container = ProviderContainer.test(overrides: _overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: DrinkTrackerScreen(initialDate: initial)),
        ),
      );
      // Drain the post-frame callback that calls notifier.setTrackedAt.
      await tester.pump(const Duration(milliseconds: 200));

      final state = container.read(drinkTrackerProvider);
      expect(state.trackedAt, equals(initial));
    });

    testWidgets(
      'drag inside the suggestion list does not collapse the dropdown',
      (tester) async {
        // The whole point of switching DrinkSearch from OverlayPortal to an
        // inline Column: a user scrolling through tea varieties must not
        // make the menu disappear. Pin that invariant here so a future
        // reintroduction of the overlay fails loudly.
        final repo = FakeDrinkRepository()
          ..seedDrinks([
            testDrink(id: 'tee-1', name: 'Schwarzer Tee'),
            testDrink(id: 'tee-2', name: 'Grüner Tee'),
            testDrink(id: 'tee-3', name: 'Kräutertee'),
            testDrink(id: 'tee-4', name: 'Rooibos Tee'),
            testDrink(id: 'kaffee', name: 'Kaffee'),
          ]);

        await tester.pumpWithProviders(
          const DrinkTrackerScreen(),
          overrides: _overrides(drinkRepo: repo),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Focus the search field and type a query that matches multiple
        // teas so the suggestion list renders with several items.
        await tester.tap(find.byKey(DrinkSearch.searchFieldKey));
        await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Tee');
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(DrinkSearch.suggestionsKey), findsOneWidget);
        final insideDropdown = find.descendant(
          of: find.byKey(DrinkSearch.suggestionsKey),
          matching: find.text('Schwarzer Tee'),
        );
        expect(insideDropdown, findsOneWidget);

        // Simulate the reported bug: the user drags inside the dropdown
        // trying to scroll. Must not collapse the list.
        await tester.drag(
          find.byKey(DrinkSearch.suggestionsKey),
          const Offset(0, -100),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(DrinkSearch.suggestionsKey), findsOneWidget);
        expect(insideDropdown, findsOneWidget);
      },
    );
  });
}
