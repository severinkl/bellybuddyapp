import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';
import 'package:belly_buddy/providers/recipe_collection_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/screens/recipes/my_recipes_tab.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipes_search_field.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockUserRecipeRepository repo;
  late FakeRecipeRepository collection;

  setUp(() {
    repo = MockUserRecipeRepository();
    collection = FakeRecipeRepository();
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
          recipeRepositoryProvider.overrideWithValue(collection),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: Scaffold(body: MyRecipesTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  void saved(String id, String title) {
    collection.collection = [
      ...collection.collection.where((r) => r.id != 'recipe-1'),
      testRecipe(id: id, title: title),
    ];
    collection.favorites = [FavoriteRecipe(id, DateTime(2026, 11, 20))];
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

  testWidgets('gemerkte appear with a heart', (tester) async {
    saved('g', 'Gemerktes Curry');
    await pump(
      tester,
      recipes: [testUserRecipe(id: 'a', title: 'Eigenes')],
    );

    expect(find.byType(RecipeCard), findsOneWidget);
    expect(find.byType(RecipeCollectionCard), findsOneWidget);
    expect(find.text('Gemerktes Curry'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('a search filters the gemerkte by title', (tester) async {
    saved('g', 'Gemerktes Curry');
    await pump(
      tester,
      recipes: [testUserRecipe(id: 'a', title: 'Eigenes')],
    );

    await tester.enterText(find.byType(TextField), '  CURRY ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Gemerktes Curry'), findsOneWidget);

    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCollectionCard), findsNothing);
    expect(find.text('Keine Treffer'), findsOneWidget);
  });

  group('the gemerkte match like the own ones', () {
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    testWidgets('every word a prefix of a title word, in any order', (
      tester,
    ) async {
      saved('g', 'Curry mit Reis');
      await pump(
        tester,
        recipes: [testUserRecipe(id: 'a', title: 'Eigenes')],
      );

      await search(tester, 'Reis Curry');
      expect(find.text('Curry mit Reis'), findsOneWidget);

      await search(tester, 'cur re');
      expect(find.text('Curry mit Reis'), findsOneWidget);

      // Inside a word is no match, as on the server.
      await search(tester, 'urry');
      expect(find.text('Curry mit Reis'), findsNothing);

      await search(tester, 'Curry Nudeln');
      expect(find.text('Curry mit Reis'), findsNothing);
    });

    testWidgets('only once the search runs, with the own ones', (tester) async {
      saved('g', 'Curry mit Reis');
      await pump(
        tester,
        recipes: [testUserRecipe(id: 'a', title: 'Eigenes')],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyRecipesTab)),
      );

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 100));
      // Something else rebuilds the list before the search ran.
      collection.favorites = [
        ...collection.favorites,
        FavoriteRecipe('recipe-1', DateTime(2026, 11, 21)),
      ];
      collection.collection = [...collection.collection, testRecipe()];
      await container.read(recipeCollectionProvider.notifier).refresh();
      await container.read(recipeFavoritesProvider.notifier).refresh();
      await tester.pump();
      expect(find.text('Curry mit Reis'), findsOneWidget);
      expect(find.text('Eigenes'), findsOneWidget);

      when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Curry mit Reis'), findsNothing);
      expect(find.text('Keine Treffer'), findsOneWidget);
    });
  });

  testWidgets('only gemerkte → grid, not the empty state', (tester) async {
    saved('g', 'Gemerktes Curry');
    await pump(tester, recipes: const []);

    expect(find.text('Noch keine Rezepte'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(RecipeCollectionCard), findsOneWidget);
  });

  testWidgets('no empty state while the saved ones are still loading', (
    tester,
  ) async {
    saved('g', 'Gemerktes Curry');
    when(() => repo.fetchForUser(any())).thenAnswer((_) async => []);
    when(() => repo.searchForUser(any(), any())).thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRecipeRepositoryProvider.overrideWithValue(repo),
          recipeRepositoryProvider.overrideWithValue(collection),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: const MaterialApp(home: Scaffold(body: MyRecipesTab())),
      ),
    );
    // One frame: the lists are fetched but not yet settled.
    await tester.pump();
    expect(find.text('Noch keine Rezepte'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCollectionCard), findsOneWidget);
  });

  testWidgets('a backend without the collection: no own recipes still '
      'offers the first one, with a quiet line and a retry', (tester) async {
    saved('g', 'Gemerktes Curry');
    // Before core #11: the collection's and the favourites' reads fail.
    collection
      ..collectionError = const PostgrestException(
        message: 'column recipes.meal_types does not exist',
        code: '42703',
      )
      ..favoritesError = const PostgrestException(
        message: 'offline',
        code: 'PGRST000',
      );
    await pump(tester, recipes: const []);

    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    expect(find.text(RecipeCopy.savedFailed), findsOneWidget);

    collection
      ..collectionError = null
      ..favoritesError = null;
    await tester.tap(find.text(RecipeCopy.retry));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeCollectionCard), findsOneWidget);
    expect(find.text(RecipeCopy.savedFailed), findsNothing);
  });

  testWidgets('own recipes and the saved ones failed: the own ones and the '
      'quiet line', (tester) async {
    collection.favoritesError = StateError('offline');
    await pump(
      tester,
      recipes: [testUserRecipe(id: 'a', title: 'Eigenes')],
    );

    expect(find.byType(RecipeCard), findsOneWidget);
    expect(find.text(RecipeCopy.savedFailed), findsOneWidget);
  });
}
