// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/ingredient_suggestions/ingredient_suggestions_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/widgets/common/plus_locked_card.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';
import '../../helpers/riverpod_helpers.dart';
import '../../helpers/purchases_fakes.dart';

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

    testWidgets('the groups new on opening keep „Neu" while it is open; '
        'they count as seen at once', (tester) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(IngredientSuggestionsScreen)),
      );
      expect(container.read(newIngredientSuggestionCountProvider), 0);
      expect(find.text('Neu'), findsOneWidget);
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

  group('Belly Buddy Plus, none received', () {
    const note =
        'Alternativen zu auffälligen Zutaten gibt es mit Belly Buddy Plus.';

    List<Override> none(Override plus) {
      final repo = MockIngredientRepository();
      when(
        () => repo.fetchSuggestionGroups(any()),
      ).thenAnswer((_) async => const []);
      when(() => repo.markAllSeen(any())).thenAnswer((_) async {});
      return [
        ingredientRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('test-user'),
        plus,
      ];
    }

    testWidgets('locked: the note and the link instead of the empty line', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: none(plusLockedOverrides.single),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(note), findsOneWidget);
      expect(find.byKey(PlusLink.openKey), findsOneWidget);
      expect(find.text('Keine Vorschläge vorhanden.'), findsNothing);
    });

    for (final (name, plus) in [
      ('open', plusOpenOverrides.single),
      ('switch off', plusSwitchOffOverrides.single),
    ]) {
      testWidgets('$name: today\'s empty line', (tester) async {
        await tester.pumpWithProviders(
          const IngredientSuggestionsScreen(),
          overrides: none(plus),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Keine Vorschläge vorhanden.'), findsOneWidget);
        expect(find.text(note), findsNothing);
        expect(find.byKey(PlusLink.openKey), findsNothing);
      });
    }

    testWidgets('locked with groups, a search with no match: the empty line', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const IngredientSuggestionsScreen(),
        overrides: [..._overrides(), ...plusLockedOverrides],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump();

      expect(find.text('Keine Vorschläge vorhanden.'), findsOneWidget);
      expect(find.text(note), findsNothing);
    });
  });
}
