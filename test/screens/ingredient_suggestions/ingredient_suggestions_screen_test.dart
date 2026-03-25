// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/ingredient_suggestions/ingredient_suggestions_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('IngredientSuggestionsScreen', () {
    testWidgets('renders Zutaten-Vorschläge app bar title', (tester) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Zutaten-Vorschläge'), findsOneWidget);
    });

    testWidgets('renders search field', (tester) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Suchen...'), findsOneWidget);
    });

    testWidgets('renders suggestion card for Zwiebel', (tester) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: _overrides(),
      );
      // Let initState microtask + fetchSuggestions + markAllNewAsSeen complete
      await tester.pump(const Duration(milliseconds: 200));

      // FakeIngredientRepository.fetchSuggestionGroups returns testSuggestionGroup
      // with ingredientName: 'Zwiebel'
      expect(find.text('Zwiebel'), findsOneWidget);
    });

    testWidgets('renders Vorschläge count text after loading', (tester) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Vorschlag'), findsOneWidget);
    });
  });
}
