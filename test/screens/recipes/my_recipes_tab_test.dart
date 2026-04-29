import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/my_recipes_tab.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipes_search_field.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;

  setUp(() {
    repo = MockUserRecipeRepository();
  });

  Future<void> pump(WidgetTester tester, {required List recipes}) async {
    when(
      () => repo.fetchForUser(any()),
    ).thenAnswer((_) async => recipes.cast());
    when(
      () => repo.searchForUser(any(), any()),
    ).thenAnswer((_) async => recipes.cast());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: Scaffold(body: MyRecipesTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty-state CTA when there are no recipes', (
    tester,
  ) async {
    await pump(tester, recipes: const []);
    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    expect(find.byType(RecipeCard), findsNothing);
    expect(find.byType(RecipesSearchField), findsNothing);
  });

  testWidgets('shows search field + grid when recipes exist', (tester) async {
    final recipes = [
      testUserRecipe(id: 'a', title: 'Curry'),
      testUserRecipe(id: 'b', title: 'Pasta'),
    ];
    await pump(tester, recipes: recipes);

    expect(find.byType(RecipesSearchField), findsOneWidget);
    expect(find.byType(RecipeCard), findsNWidgets(2));
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets(
    'shows search field + Keine Treffer when query yields zero results',
    (tester) async {
      final repo = MockUserRecipeRepository();
      // Initial unfiltered fetch returns 1 recipe so we land in the
      // "non-empty data + search field" UI.
      when(
        () => repo.fetchForUser(any()),
      ).thenAnswer((_) async => [testUserRecipe()]);
      // The search returns nothing.
      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRecipeRepositoryProvider.overrideWithValue(repo),
            currentUserIdProvider.overrideWithValue(testUserId),
          ],
          child: const MaterialApp(home: Scaffold(body: MyRecipesTab())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecipeCard), findsOneWidget);

      // Type into the search field; provider's debounce → searchForUser.
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(RecipesSearchField), findsOneWidget);
      expect(find.text('Keine Treffer'), findsOneWidget);
      expect(find.byType(RecipeCard), findsNothing);
    },
  );
}
