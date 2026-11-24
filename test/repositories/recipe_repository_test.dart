import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:belly_buddy/models/recipe.dart';
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

  group('fetchCollection', () {
    test('delegates to recipeService.fetchCollection', () async {
      final recipes = [
        testRecipe(),
        testRecipe(id: 'recipe-2', title: 'Suppe'),
      ];
      when(
        () => recipeService.fetchCollection(),
      ).thenAnswer((_) async => recipes);

      final result = await repo.fetchCollection();

      expect(result, same(recipes));
      verify(() => recipeService.fetchCollection()).called(1);
    });

    test('retries a failing read', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
      var calls = 0;
      final recipes = [testRecipe()];
      when(() => recipeService.fetchCollection()).thenAnswer((_) async {
        if (++calls == 1) throw Exception('backend down');
        return recipes;
      });

      // retryAsync waits 2 s before the second attempt.
      final result = await repo.fetchCollection();

      expect(result, same(recipes));
      expect(calls, 2);
      expect(
        logs,
        contains('RecipeRepository [ERROR]: fetchCollection (attempt 1/3)'),
      );
    });

    test('fails at once on a PostgREST error (schema, permission)', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
      var calls = 0;
      when(() => recipeService.fetchCollection()).thenAnswer((_) async {
        calls++;
        throw const PostgrestException(
          message: 'column missing',
          code: '42703',
        );
      });

      await expectLater(
        repo.fetchCollection(),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1);
      expect(
        logs,
        contains(startsWith('RecipeRepository [ERROR]: fetchCollection')),
      );
    });
  });

  group('fetchFavorites', () {
    test('delegates to recipeService.fetchFavorites', () async {
      final favorites = [
        FavoriteRecipe('recipe-1', DateTime.utc(2026, 11, 20)),
      ];
      when(
        () => recipeService.fetchFavorites(any()),
      ).thenAnswer((_) async => favorites);

      final result = await repo.fetchFavorites(testUserId);

      expect(result, same(favorites));
      verify(() => recipeService.fetchFavorites(testUserId)).called(1);
    });
  });

  group('fetchIntoleranceRules', () {
    test('delegates to recipeService.fetchIntoleranceRules', () async {
      final rules = testIntoleranceRules();
      when(
        () => recipeService.fetchIntoleranceRules(),
      ).thenAnswer((_) async => rules);

      expect(await repo.fetchIntoleranceRules(), same(rules));
      verify(() => recipeService.fetchIntoleranceRules()).called(1);
    });

    test('passes a missing table through as null', () async {
      when(
        () => recipeService.fetchIntoleranceRules(),
      ).thenAnswer((_) async => null);

      expect(await repo.fetchIntoleranceRules(), isNull);
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
