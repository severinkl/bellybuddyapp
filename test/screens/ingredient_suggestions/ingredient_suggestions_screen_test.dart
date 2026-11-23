// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/ingredient_suggestions/ingredient_suggestions_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('IngredientSuggestionsScreen', () {
    testWidgets('the app bar is titled Alternativen', (tester) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alternativen'), findsOneWidget);
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

    testWidgets('a failed reload (offline resume) keeps the open groups', (
      tester,
    ) async {
      final repo = MockIngredientRepository();
      when(
        () => repo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => [testSuggestionGroup()]);
      when(() => repo.markAllSeen(any())).thenAnswer((_) async {});
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: [
          ingredientRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Zwiebel'), findsOneWidget);

      // The resume refresh reloads them, offline.
      when(
        () => repo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => throw Exception('offline'));
      await ProviderScope.containerOf(
        tester.element(find.byType(IngredientSuggestionsScreen)),
      ).read(ingredientSuggestionProvider.notifier).fetchSuggestions();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Fehler beim Laden der Vorschläge.'), findsNothing);
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
