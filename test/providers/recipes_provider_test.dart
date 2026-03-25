import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/recipes_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockRecipeRepository mockRepo;

  setUp(() {
    mockRepo = MockRecipeRepository();
  });

  /// build() triggers _loadAll() immediately — set up mocks BEFORE creating
  /// the container so the provider's async build work finds them immediately.
  ///
  /// Then use [_initRecipes] to await the provider's initial async work.
  ProviderContainer makeContainer({
    String? userId = testUserId,
    List<Object>? recipes,
    Set<String>? favoriteIds,
  }) {
    when(
      () => mockRepo.fetchAll(),
    ).thenAnswer((_) async => recipes?.cast() ?? [testRecipe()]);
    when(
      () => mockRepo.fetchFavoriteIds(any()),
    ).thenAnswer((_) async => favoriteIds ?? {});

    return createContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(mockRepo),
        currentUserIdProvider.overrideWithValue(userId),
      ],
    );
  }

  /// Reads the provider to trigger build (and therefore _loadAll), then waits
  /// for the async _loadRecipes / _loadFavorites futures to complete.
  Future<void> initRecipes(ProviderContainer container) async {
    // listen() initializes the provider and keeps it alive
    container.listen(recipesProvider, (prev, next) {});
    // Pump enough microtask turns for the async work to settle
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('RecipesNotifier build / _loadRecipes', () {
    test('populates allRecipes and filtered on build', () async {
      final recipes = [
        testRecipe(id: 'r-1', title: 'Pasta'),
        testRecipe(id: 'r-2', title: 'Salat'),
      ];
      final container = makeContainer(recipes: recipes);
      await initRecipes(container);

      final state = container.read(recipesProvider);
      expect(state.allRecipes, hasLength(2));
      expect(state.filtered, hasLength(2));
      expect(state.isLoading, isFalse);
    });

    test('sets isLoading false when repo throws', () async {
      when(() => mockRepo.fetchAll()).thenThrow(Exception('db error'));
      when(
        () => mockRepo.fetchFavoriteIds(any()),
      ).thenAnswer((_) async => <String>{});

      final container = createContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
      );
      await initRecipes(container);

      final state = container.read(recipesProvider);
      // isLoading must be false after the fetch attempt regardless of outcome
      expect(state.isLoading, isFalse);
      // allRecipes stays empty on error
      expect(state.allRecipes, isEmpty);
    });
  });

  group('RecipesNotifier.setSearch', () {
    test('filters recipes by title (case-insensitive)', () async {
      final recipes = [
        testRecipe(id: 'r-1', title: 'Pasta'),
        testRecipe(id: 'r-2', title: 'Salat'),
      ];
      final container = makeContainer(recipes: recipes);
      await initRecipes(container);

      container.read(recipesProvider.notifier).setSearch('past');

      final state = container.read(recipesProvider);
      expect(state.filtered, hasLength(1));
      expect(state.filtered.first.title, equals('Pasta'));
    });

    test('empty search string shows all recipes', () async {
      final recipes = [
        testRecipe(id: 'r-1', title: 'Pasta'),
        testRecipe(id: 'r-2', title: 'Salat'),
      ];
      final container = makeContainer(recipes: recipes);
      await initRecipes(container);

      container.read(recipesProvider.notifier).setSearch('past');
      container.read(recipesProvider.notifier).setSearch('');

      expect(container.read(recipesProvider).filtered, hasLength(2));
    });
  });

  group('RecipesNotifier.toggleFilter', () {
    test('adds filter tag and filters recipes', () async {
      final recipes = [
        testRecipe(id: 'r-1', title: 'Pasta', tags: ['vegetarisch']),
        testRecipe(id: 'r-2', title: 'Steak', tags: ['fleisch']),
      ];
      final container = makeContainer(recipes: recipes);
      await initRecipes(container);

      container.read(recipesProvider.notifier).toggleFilter('vegetarisch');

      final state = container.read(recipesProvider);
      expect(state.filtered, hasLength(1));
      expect(state.filtered.first.title, equals('Pasta'));
    });

    test('removes filter tag when toggled twice', () async {
      final recipes = [
        testRecipe(id: 'r-1', title: 'Pasta', tags: ['vegetarisch']),
        testRecipe(id: 'r-2', title: 'Steak', tags: ['fleisch']),
      ];
      final container = makeContainer(recipes: recipes);
      await initRecipes(container);

      final notifier = container.read(recipesProvider.notifier);
      notifier.toggleFilter('vegetarisch');
      notifier.toggleFilter('vegetarisch');

      expect(container.read(recipesProvider).filtered, hasLength(2));
    });
  });

  group('RecipesNotifier.toggleFavorite', () {
    test('adds recipe to favorites', () async {
      final container = makeContainer();
      await initRecipes(container);

      when(() => mockRepo.addFavorite(any(), any())).thenAnswer((_) async {});

      await container.read(recipesProvider.notifier).toggleFavorite('recipe-1');

      expect(container.read(recipesProvider).favorites, contains('recipe-1'));
    });

    test('removes recipe from favorites when already favorited', () async {
      final container = makeContainer(favoriteIds: {'recipe-1'});
      await initRecipes(container);

      when(
        () => mockRepo.removeFavorite(any(), any()),
      ).thenAnswer((_) async {});

      await container.read(recipesProvider.notifier).toggleFavorite('recipe-1');

      expect(
        container.read(recipesProvider).favorites,
        isNot(contains('recipe-1')),
      );
    });
  });
}
