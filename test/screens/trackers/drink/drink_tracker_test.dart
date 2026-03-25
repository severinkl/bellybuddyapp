// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/trackers/drink/drink_tracker_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  drinkRepositoryProvider.overrideWithValue(FakeDrinkRepository()),
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
  });
}
