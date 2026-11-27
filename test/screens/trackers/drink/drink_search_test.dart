import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/trackers/drink/drink_tracker_screen.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/drink_search.dart';
import 'package:belly_buddy/screens/trackers/drink/widgets/quick_drink_grid.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/riverpod_helpers.dart';

void main() {
  testWidgets('a synonym finds the drink under its name, without „neu"', (
    tester,
  ) async {
    final repo = FakeDrinkRepository()
      ..seedDrinks([
        testDrink(),
        testDrink(id: 'lim', name: 'Limonade', synonyms: ['Kracherl']),
      ]);
    await tester.pumpWithProviders(
      const DrinkTrackerScreen(),
      overrides: [
        entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
        drinkRepositoryProvider.overrideWithValue(repo),
        buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
        currentUserIdProvider.overrideWithValue('test-user'),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(QuickDrinkGrid.searchTileKey));
    await tester.pump();
    await tester.enterText(find.byKey(DrinkSearch.searchFieldKey), 'Kracherl');
    await tester.pump(const Duration(milliseconds: 500));

    final list = find.byKey(DrinkSearch.suggestionsKey);
    expect(
      find.descendant(of: list, matching: find.text('Limonade')),
      findsOneWidget,
    );
    expect(find.textContaining('hinzufügen'), findsNothing);
    expect(
      find.descendant(of: list, matching: find.text('Kracherl')),
      findsNothing,
    );
  });
}
