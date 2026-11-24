import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/adapted_recipe.dart';
import 'package:belly_buddy/models/recipe.dart';
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

Map<String, dynamic> _collectionRow({
  String id = 'recipe-1',
  String title = 'Testrezept',
}) => {
  'id': id,
  'title': title,
  'description': null,
  'cook_time': '20 Min',
  'servings': 2,
  'image_url': null,
  'meal_types': ['mittag'],
  'diet_tags': ['vegan', 'vegetarisch'],
  'source_name': 'Beispielküche',
  'source_url': 'https://example.org/$id',
  'instructions': ['Alles kochen.'],
  'ingredients': <dynamic>[],
  'created_at': '2026-11-24T08:00:00+00:00',
  'recipe_ingredients': [
    {
      'position': 0,
      'amount_text': '200 g',
      'name': 'Reis',
      'allergens': <dynamic>[],
      'low_at_amount': false,
      'ingredient': {
        'id': 'ing-Reis',
        'name': 'Reis',
        'fodmap_fructans': false,
        'fodmap_gos': false,
        'fodmap_lactose': false,
        'fodmap_fructose': false,
        'fodmap_sorbitol': false,
        'fodmap_mannitol': false,
      },
    },
  ],
};

/// `client.from(table).select(...)` returning [filter]; the query builder is
/// returned so tests can verify the select string.
MockSupabaseQueryBuilder _fromTable(
  MockSupabaseClient client,
  String table,
  MockPostgrestFilterBuilder filter,
) {
  final queryBuilder = MockSupabaseQueryBuilder();
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(() => queryBuilder.select(any())).thenAnswer((_) => filter);
  return queryBuilder;
}

/// `app_config` select whose `maybeSingle()` resolves with [row].
({MockSupabaseQueryBuilder query, MockPostgrestFilterBuilder filter})
_stubRulesRow(MockSupabaseClient client, Map<String, dynamic>? row) {
  final filter = MockPostgrestFilterBuilder();
  final query = _fromTable(client, 'app_config', filter);
  when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
  when(() => filter.maybeSingle()).thenAnswer((_) => settleMaybeSingle(row));
  return (query: query, filter: filter);
}

/// Collects [debugPrint] output (the [AppLogger] lines) for this test.
List<String> _captureLogs() {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  addTearDown(() => debugPrint = original);
  return logs;
}

/// A 200 answer of `adapt-recipe` with one ingredient.
Map<String, dynamic> _adaptAnswer() => {
  'recipe_id': 'recipe-1',
  'title': 'Risotto',
  'ingredients': [
    {
      'amount': '200 g',
      'name': 'Reis',
      'replaces': null,
      'status': 'ok',
      'ingredient_id': 'ing-Reis',
    },
  ],
  'removed': <dynamic>[],
  'steps': [
    {'text': 'Kochen.', 'changed': false},
  ],
  'note': '',
};

void main() {
  late MockSupabaseClient client;
  late RecipeService service;

  setUp(() {
    client = MockSupabaseClient();
    service = RecipeService(client);
  });

  group('RecipeService.fetchCollection', () {
    late SettlableFilterBuilder filter;
    late MockSupabaseQueryBuilder queryBuilder;

    void stubRows(List<Map<String, dynamic>> rows) {
      filter = SettlableFilterBuilder(Future.value(rows));
      queryBuilder = _fromTable(client, 'recipes', filter);
      when(() => filter.isFilter(any(), any())).thenAnswer((_) => filter);
      when(
        () => filter.order(
          any(),
          ascending: any(named: 'ascending'),
          referencedTable: any(named: 'referencedTable'),
        ),
      ).thenAnswer((_) => filter);
    }

    test(
      "fetchCollection selects the contract's columns, hides hidden rows, orders",
      () async {
        stubRows([]);

        await service.fetchCollection();

        verify(
          () => queryBuilder.select(RecipeService.collectionSelect),
        ).called(1);
        verify(() => filter.isFilter('hidden', false)).called(1);
        verify(() => filter.order('created_at', ascending: false)).called(1);
        verify(
          () => filter.order(
            'position',
            ascending: true,
            referencedTable: 'recipe_ingredients',
          ),
        ).called(1);
      },
    );

    test('parses the rows', () async {
      stubRows([
        _collectionRow(),
        _collectionRow(id: 'recipe-2', title: 'Suppe'),
      ]);

      final result = await service.fetchCollection();

      expect(result.map((r) => r.title), ['Testrezept', 'Suppe']);
      expect(result.first.mealTypes, [MealType.lunch]);
      expect(result.first.ingredients.single.amount, '200 g');
      expect(result.first.ingredients.single.catalogId, 'ing-Reis');
    });

    test('rethrows a failed read', () async {
      final logs = _captureLogs();
      filter = SettlableFilterBuilder(
        Future<PostgrestList>.error(Exception('offline')),
      );
      _fromTable(client, 'recipes', filter);
      when(() => filter.isFilter(any(), any())).thenAnswer((_) => filter);
      when(
        () => filter.order(
          any(),
          ascending: any(named: 'ascending'),
          referencedTable: any(named: 'referencedTable'),
        ),
      ).thenAnswer((_) => filter);

      await expectLater(service.fetchCollection(), throwsException);
      expect(logs, contains('RecipeService [ERROR]: fetchCollection failed'));
    });
  });

  group('RecipeService.collectionSelect', () {
    test('collectionSelect names every contract field', () {
      for (final field in [
        'meal_types',
        'diet_tags',
        'source_name',
        'source_url',
        'instructions',
        'allergens',
        'low_at_amount',
        'ingredient:ingredients(',
        'fodmap_fructans',
        'fodmap_mannitol',
      ]) {
        expect(RecipeService.collectionSelect, contains(field), reason: field);
      }
    });
  });

  group('RecipeService.fetchFavorites', () {
    test('fetchFavorites newest first', () async {
      final filter = SettlableFilterBuilder(
        Future.value([
          {'recipe_id': 'recipe-3', 'created_at': '2026-11-23T18:30:00+00:00'},
          {'recipe_id': 'recipe-1', 'created_at': '2026-11-20T07:00:00+00:00'},
        ]),
      );
      final queryBuilder = _fromTable(client, 'user_favorite_recipes', filter);
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      when(
        () => filter.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => filter);

      final result = await service.fetchFavorites(testUserId);

      verify(() => queryBuilder.select('recipe_id,created_at')).called(1);
      verify(() => filter.eq('user_id', testUserId)).called(1);
      verify(() => filter.order('created_at', ascending: false)).called(1);
      expect(result.map((f) => f.recipeId), ['recipe-3', 'recipe-1']);
      expect(result.first.at, DateTime.utc(2026, 11, 23, 18, 30));
      expect(result.last.at, DateTime.utc(2026, 11, 20, 7));
    });
  });

  group('RecipeService.fetchIntoleranceRules', () {
    test('a row with the published table is parsed', () async {
      final stub = _stubRulesRow(client, {'value': kTestIntoleranceRulesJson});

      final rules = await service.fetchIntoleranceRules();

      verify(() => stub.query.select('value')).called(1);
      verify(() => stub.filter.eq('key', 'intolerance_rules')).called(1);
      verify(() => stub.filter.maybeSingle()).called(1);
      expect(rules!.byName, hasLength(13));
      expect(rules['Weizen']!.allergens, {'weizen'});
    });

    test('no row → null', () async {
      final logs = _captureLogs();
      _stubRulesRow(client, null);

      expect(await service.fetchIntoleranceRules(), isNull);
      expect(logs, ['RecipeService [WARN]: intolerance_rules missing']);
    });

    test('a value that is not JSON → null', () async {
      final logs = _captureLogs();
      _stubRulesRow(client, {'value': 'kein JSON'});

      expect(await service.fetchIntoleranceRules(), isNull);
      expect(logs, [
        'RecipeService [WARN]: intolerance_rules is not a JSON object',
      ]);
    });

    test('a value that is not a JSON object → null', () async {
      final logs = _captureLogs();
      _stubRulesRow(client, {'value': '["Laktose"]'});

      expect(await service.fetchIntoleranceRules(), isNull);
      expect(logs, [
        'RecipeService [WARN]: intolerance_rules is not a JSON object',
      ]);
    });

    test('rethrows a failed read', () async {
      final logs = _captureLogs();
      final filter = mockSelect(client, table: 'app_config');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      when(() => filter.maybeSingle()).thenAnswer(
        (_) => SettlableMapNullable(Future.error(Exception('offline'))),
      );

      await expectLater(service.fetchIntoleranceRules(), throwsException);
      expect(
        logs,
        contains('RecipeService [ERROR]: fetchIntoleranceRules failed'),
      );
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
  group('RecipeService.adapt', () {
    late MockFunctionsClient functions;

    setUp(() {
      functions = mockFunctions(client);
    });

    void stubAnswer(Object? data) => when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => FunctionResponse(data: data, status: 200));

    void stubThrow(Object error) => when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenThrow(error);

    Future<AdaptFailure?> failureOf(Future<Object?> call) async {
      try {
        await call;
        return null;
      } on AdaptRecipeException catch (e) {
        return e.failure;
      }
    }

    test('the body is exactly the recipe id', () async {
      stubAnswer(_adaptAnswer());

      final adapted = await service.adapt('recipe-1');

      final captured = verify(
        () => functions.invoke('adapt-recipe', body: captureAny(named: 'body')),
      ).captured;
      expect(captured.single, {'recipe_id': 'recipe-1'});
      expect(adapted.title, 'Risotto');
      expect(adapted.ingredients.single.name, 'Reis');
    });

    test('error codes map', () async {
      for (final (status, code, failure, level) in [
        (409, 'nothing_to_adapt', AdaptFailure.nothingToAdapt, 'WARN'),
        (409, 'cannot_judge', AdaptFailure.cannotJudge, 'WARN'),
        (429, 'throttled', AdaptFailure.later, 'WARN'),
        (429, 'ai_busy', AdaptFailure.later, 'WARN'),
        (429, null, AdaptFailure.later, 'WARN'),
        (422, 'adapt_failed', AdaptFailure.failed, 'ERROR'),
        (502, 'ai_error', AdaptFailure.failed, 'ERROR'),
        (404, 'recipe_not_found', AdaptFailure.failed, 'ERROR'),
        (400, 'invalid_request', AdaptFailure.failed, 'ERROR'),
        (401, null, AdaptFailure.failed, 'ERROR'),
        (500, null, AdaptFailure.failed, 'ERROR'),
        (409, 'something_new', AdaptFailure.failed, 'ERROR'),
      ]) {
        final logs = _captureLogs();
        stubThrow(
          FunctionsHttpException(
            status: status,
            details: {'code': ?code, 'error': 'Eine Meldung vom Server.'},
          ),
        );

        expect(
          await failureOf(service.adapt('recipe-1')),
          failure,
          reason: '$status $code',
        );
        expect(
          logs.first,
          startsWith('RecipeService [$level]: adapt'),
          reason: '$status $code',
        );
      }
    });

    test('an error body that is not JSON → failed', () async {
      final logs = _captureLogs();
      stubThrow(
        const FunctionsHttpException(status: 502, details: 'Bad Gateway'),
      );

      expect(await failureOf(service.adapt('recipe-1')), AdaptFailure.failed);
      expect(logs.first, 'RecipeService [ERROR]: adapt failed (502)');
    });

    test('transport failure', () async {
      final logs = _captureLogs();
      stubThrow(const FunctionsFetchException(details: 'offline'));

      expect(await failureOf(service.adapt('recipe-1')), AdaptFailure.failed);
      expect(logs.first, startsWith('RecipeService [ERROR]: adapt'));
    });

    test('an answer that is not a map → failed', () async {
      final logs = _captureLogs();
      stubAnswer('kein JSON');

      expect(await failureOf(service.adapt('recipe-1')), AdaptFailure.failed);
      expect(logs.first, startsWith('RecipeService [ERROR]: adapt'));
    });

    test('an answer that fails fromJson → failed', () async {
      final logs = _captureLogs();
      stubAnswer(_adaptAnswer()..remove('ingredients'));

      expect(await failureOf(service.adapt('recipe-1')), AdaptFailure.failed);
      expect(logs.first, 'RecipeService [ERROR]: adapt: unreadable answer');
    });
  });
}
