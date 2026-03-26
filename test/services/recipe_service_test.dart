import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/recipe_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

/// Stubs [filter] so that `await filter` resolves with an empty list.
void _stubFilterFuture(MockPostgrestFilterBuilder filter) {
  when(
    () => filter.then<dynamic>(any(), onError: any(named: 'onError')),
  ).thenAnswer((inv) {
    final onValue = inv.positionalArguments[0] as Function;
    return Future<PostgrestList>.value([]).then((v) => onValue(v));
  });
}

Map<String, dynamic> _recipeRow({
  String id = 'recipe-1',
  String title = 'Testrezept',
}) => {
  'id': id,
  'title': title,
  'description': null,
  'image_url': null,
  'cook_time': null,
  'servings': null,
  'ingredients': <dynamic>[],
  'instructions': <dynamic>[],
  'tags': <dynamic>[],
  'created_at': null,
};

void main() {
  late MockSupabaseClient client;
  late RecipeService service;

  setUp(() {
    client = MockSupabaseClient();
    service = RecipeService(client);
  });

  group('RecipeService.fetchAll', () {
    test('returns list of Recipe from DB rows', () async {
      final fb = mockSelectRows(
        client,
        table: 'recipes',
        rows: [
          _recipeRow(),
          _recipeRow(id: 'recipe-2', title: 'Zweites Rezept'),
        ],
      );
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchAll();

      expect(result, hasLength(2));
      expect(result.first.id, 'recipe-1');
      expect(result.first.title, 'Testrezept');
      expect(result[1].title, 'Zweites Rezept');
    });

    test('returns empty list when no recipes exist', () async {
      final fb = mockSelectRows(client, table: 'recipes', rows: []);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchAll();

      expect(result, isEmpty);
    });

    test('orders by title', () async {
      final fb = mockSelectRows(client, table: 'recipes', rows: []);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      await service.fetchAll();

      verify(
        () => fb.order('title', ascending: any(named: 'ascending')),
      ).called(1);
    });
  });

  group('RecipeService.fetchFavoriteIds', () {
    test('returns Set of recipe_id strings', () async {
      final fb = mockSelectRows(
        client,
        table: 'user_favorite_recipes',
        rows: [
          {'recipe_id': 'recipe-1'},
          {'recipe_id': 'recipe-3'},
        ],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);

      final result = await service.fetchFavoriteIds(testUserId);

      expect(result, isA<Set<String>>());
      expect(result, containsAll(['recipe-1', 'recipe-3']));
      expect(result, hasLength(2));
    });

    test('returns empty set when no favorites', () async {
      final fb = mockSelectRows(
        client,
        table: 'user_favorite_recipes',
        rows: [],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);

      final result = await service.fetchFavoriteIds(testUserId);

      expect(result, isEmpty);
    });

    test('filters by user_id', () async {
      final fb = mockSelectRows(
        client,
        table: 'user_favorite_recipes',
        rows: [],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);

      await service.fetchFavoriteIds(testUserId);

      verify(() => fb.eq('user_id', testUserId)).called(1);
    });
  });

  group('RecipeService.addFavorite', () {
    test('inserts user_id and recipe_id into user_favorite_recipes', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder();
      when(
        () => client.from('user_favorite_recipes'),
      ).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.insert(any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.addFavorite(testUserId, 'recipe-1');

      final captured =
          verify(() => queryBuilder.insert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['user_id'], testUserId);
      expect(captured['recipe_id'], 'recipe-1');
    });

    test('completes without error', () async {
      final fb = mockInsert(client, table: 'user_favorite_recipes');
      _stubFilterFuture(fb);

      await expectLater(service.addFavorite(testUserId, 'recipe-1'), completes);
    });
  });

  group('RecipeService.removeFavorite', () {
    test('deletes by user_id and recipe_id', () async {
      final fb = mockDelete(client, table: 'user_favorite_recipes');
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.removeFavorite(testUserId, 'recipe-1');

      verify(() => client.from('user_favorite_recipes').delete()).called(1);
      verify(() => fb.eq('user_id', testUserId)).called(1);
      verify(() => fb.eq('recipe_id', 'recipe-1')).called(1);
    });

    test('completes without error', () async {
      final fb = mockDelete(client, table: 'user_favorite_recipes');
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await expectLater(
        service.removeFavorite(testUserId, 'recipe-1'),
        completes,
      );
    });
  });
}
