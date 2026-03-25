import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/recipe_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockRecipeService recipeService;
  late RecipeRepository repo;

  setUp(() {
    recipeService = MockRecipeService();
    repo = RecipeRepository(recipeService);
  });

  group('fetchAll', () {
    test('delegates to recipeService.fetchAll and returns list', () async {
      final recipes = [
        testRecipe(),
        testRecipe(id: 'recipe-2', title: 'Suppe'),
      ];
      when(() => recipeService.fetchAll()).thenAnswer((_) async => recipes);

      final result = await repo.fetchAll();

      expect(result, equals(recipes));
      verify(() => recipeService.fetchAll()).called(1);
    });
  });

  group('fetchFavoriteIds', () {
    test('delegates to recipeService.fetchFavoriteIds', () async {
      final ids = {'recipe-1', 'recipe-2'};
      when(
        () => recipeService.fetchFavoriteIds(any()),
      ).thenAnswer((_) async => ids);

      final result = await repo.fetchFavoriteIds(testUserId);

      expect(result, equals(ids));
      verify(() => recipeService.fetchFavoriteIds(testUserId)).called(1);
    });
  });

  group('addFavorite', () {
    test(
      'delegates to recipeService.addFavorite with userId and recipeId',
      () async {
        when(
          () => recipeService.addFavorite(any(), any()),
        ).thenAnswer((_) async {});

        await repo.addFavorite(testUserId, 'recipe-1');

        verify(
          () => recipeService.addFavorite(testUserId, 'recipe-1'),
        ).called(1);
      },
    );
  });

  group('removeFavorite', () {
    test(
      'delegates to recipeService.removeFavorite with userId and recipeId',
      () async {
        when(
          () => recipeService.removeFavorite(any(), any()),
        ).thenAnswer((_) async {});

        await repo.removeFavorite(testUserId, 'recipe-1');

        verify(
          () => recipeService.removeFavorite(testUserId, 'recipe-1'),
        ).called(1);
      },
    );
  });
}
