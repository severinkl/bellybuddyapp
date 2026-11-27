import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/ingredient_service.dart';

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

void main() {
  late MockSupabaseClient client;
  late IngredientService service;

  setUp(() {
    client = MockSupabaseClient();
    service = IngredientService(client);
  });

  group('IngredientService.search', () {
    /// Stubs the select chain of both search queries (prefix and
    /// contains), which resolve with the same [rows].
    SettlableFilterBuilder stubSearch(List<Map<String, dynamic>> rows) {
      final fb = mockSelectRows(client, table: 'ingredients', rows: rows);
      when(() => fb.ilike(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);
      return fb;
    }

    test('maps rows to results, once each', () async {
      stubSearch([
        {
          'id': 'ing-1',
          'name': 'Rote Zwiebel',
          'added_by_user_id': 'other-user',
        },
        {'id': 'ing-2', 'name': 'Zwiebel', 'added_by_user_id': testUserId},
      ]);

      final result = await service.search('zwiebel', userId: testUserId);

      // Both queries returned both rows: still one result per row.
      expect(result.map((r) => r.id), ['ing-2', 'ing-1']);
      expect(result.first.name, 'Zwiebel');
      expect(result.first.isOwn, isTrue);
      expect(result.last.isOwn, isFalse);
    });

    test('sets isOwn=false when userId is null', () async {
      stubSearch([
        {'id': 'ing-1', 'name': 'Zwiebel', 'added_by_user_id': testUserId},
      ]);

      final result = await service.search('zwi', userId: null);

      // null userId never matches added_by_user_id
      expect(result.first.isOwn, isFalse);
    });

    test('asks for names starting with the query (ordered) and for names '
        'containing it', () async {
      final fb = stubSearch([]);

      await service.search('Hafer', userId: testUserId);

      verify(() => fb.ilike('name', 'Hafer%')).called(1);
      verify(() => fb.ilike('name', '%Hafer%')).called(1);
      verify(() => fb.order('name', ascending: true)).called(2);
    });

    test('ranks exact, then prefix, then word start, then contains', () async {
      stubSearch([
        {'id': '1', 'name': 'Hafermilch', 'added_by_user_id': null},
        {
          'id': '2',
          'name': 'glutenfreie Haferflocken',
          'added_by_user_id': null,
        },
        {'id': '3', 'name': 'Haferkleie', 'added_by_user_id': null},
        {'id': '4', 'name': 'Schafermilch', 'added_by_user_id': null},
        {'id': '5', 'name': 'Haferflocken', 'added_by_user_id': null},
      ]);

      final result = await service.search('haferflocken', userId: testUserId);

      expect(result.map((r) => r.name), [
        'Haferflocken',
        'glutenfreie Haferflocken',
      ]);

      final hafer = await service.search('Hafer', userId: testUserId);
      expect(hafer.map((r) => r.name), [
        'Haferkleie',
        'Hafermilch',
        'Haferflocken',
        'glutenfreie Haferflocken',
        'Schafermilch',
      ]);
    });
  });

  group('IngredientService.insertIfNew', () {
    test('returns early without a call when userId is null', () async {
      await service.insertIfNew('Zwiebel', userId: null);
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
      verifyNever(() => client.from(any()));
    });

    test('calls ensure_ingredient with the name', () async {
      when(
        () => client.rpc('ensure_ingredient', params: any(named: 'params')),
      ).thenAnswer((_) => SettlableFilterBuilder(Future.value([])));

      await service.insertIfNew('Zwiebel', userId: testUserId);

      verify(
        () => client.rpc('ensure_ingredient', params: {'p_name': 'Zwiebel'}),
      ).called(1);
      verifyNever(() => client.from(any()));
    });

    test('errors surface', () async {
      when(
        () => client.rpc('ensure_ingredient', params: any(named: 'params')),
      ).thenAnswer(
        (_) => SettlableFilterBuilder(
          Future.error(
            const PostgrestException(message: 'empty name', code: '22023'),
          ),
        ),
      );

      await expectLater(
        service.insertIfNew('Zwiebel', userId: testUserId),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '22023'),
        ),
      );
    });
  });

  group('IngredientService.deleteUserIngredient', () {
    test('calls delete with eq(id)', () async {
      final fb = mockDelete(client, table: 'ingredients');
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.deleteUserIngredient('ing-1');

      verify(() => client.from('ingredients').delete()).called(1);
      verify(() => fb.eq('id', 'ing-1')).called(1);
    });
  });

  group('IngredientService.fetchSuggestions', () {
    test('returns list of raw maps from ingredient_suggestions join', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredient_suggestions',
        rows: [
          {
            'id': 'sug-1',
            'detected_ingredient_id': 'ing-1',
            'helptext': null,
            'meal_id': 'meal-1',
            'seen_at': null,
            'dismissed_at': null,
            'ingredients': {
              'id': 'ing-1',
              'name': 'Zwiebel',
              'image_url': null,
            },
          },
        ],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);

      final result = await service.fetchSuggestions(testUserId);

      expect(result, hasLength(1));
      expect(result.first['id'], 'sug-1');
    });

    test('filters by user_id and dismissed_at is null', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredient_suggestions',
        rows: [],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);

      await service.fetchSuggestions(testUserId);

      verify(() => fb.eq('user_id', testUserId)).called(1);
      verify(() => fb.isFilter('dismissed_at', null)).called(1);
    });
  });

  group('IngredientService.fetchReplacements', () {
    test('returns empty list without DB call when ids is empty', () async {
      final result = await service.fetchReplacements([]);
      expect(result, isEmpty);
      verifyNever(() => client.from(any()));
    });

    test('calls inFilter with provided suggestion ids', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredient_suggestion_replacements',
        rows: [
          {
            'suggestion_id': 'sug-1',
            'ingredients': {'id': 'ing-2', 'name': 'Lauch', 'image_url': null},
          },
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      when(() => fb.order(any())).thenAnswer((_) => fb);

      final result = await service.fetchReplacements(['sug-1', 'sug-2']);

      expect(result, hasLength(1));
      verify(() => fb.inFilter('suggestion_id', ['sug-1', 'sug-2'])).called(1);
      // Rows of one transaction share created_at: id breaks the tie.
      verifyInOrder([() => fb.order('created_at'), () => fb.order('id')]);
    });
  });

  group('IngredientService.fetchMealDetails', () {
    test('returns empty list without DB call when ids is empty', () async {
      final result = await service.fetchMealDetails([]);
      expect(result, isEmpty);
      verifyNever(() => client.from(any()));
    });

    test('calls inFilter with provided meal ids', () async {
      final fb = mockSelectRows(
        client,
        table: 'meal_entries',
        rows: [
          {
            'id': 'meal-1',
            'title': 'Testmahlzeit',
            'tracked_at': '2026-03-25T12:00:00.000',
            'image_url': null,
          },
        ],
      );
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);

      final result = await service.fetchMealDetails(['meal-1', 'meal-2']);

      expect(result, hasLength(1));
      verify(() => fb.inFilter('id', ['meal-1', 'meal-2'])).called(1);
    });

    test('also loads the meals\' ingredients (to name a suggestion whose '
        'ingredient row is hidden)', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      final fb = SettlableFilterBuilder(Future.value([]));
      when(() => client.from('meal_entries')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select(any())).thenAnswer((_) => fb);
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);

      await service.fetchMealDetails(['meal-1']);

      final columns =
          verify(() => queryBuilder.select(captureAny())).captured.single
              as String;
      expect(columns.split(RegExp(r',\s*')), contains('ingredients'));
    });
  });

  group('IngredientService.fetchMealsSince', () {
    test('pages the user\'s meals since the wall-clock bound', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      final fb = SettlableFilterBuilder(Future.value([]));
      final paged = _PagedTransform([
        List.generate(
          IngredientService.mealPageSize,
          (i) => {'id': 'm$i', 'tracked_at': '2026-11-01T12:00:00+00:00'},
        ),
        [
          {'id': 'last', 'tracked_at': '2026-11-01T11:00:00+00:00'},
        ],
      ]);
      when(() => client.from('meal_entries')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select(any())).thenAnswer((_) => fb);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => paged);

      final rows = await service.fetchMealsSince(
        testUserId,
        DateTime(2026, 5, 31),
      );

      expect(rows, hasLength(IngredientService.mealPageSize + 1));
      expect(paged.ranges, [(0, 999), (1000, 1999)]);
      verify(
        () => queryBuilder.select('id, tracked_at, ingredients'),
      ).called(2);
      verify(() => fb.eq('user_id', testUserId)).called(2);
      verify(() => fb.gte('tracked_at', '2026-05-31T00:00:00.000Z')).called(2);
    });
  });

  group('IngredientService.markAllSeen', () {
    test('returns early without DB call when ids is empty', () async {
      await service.markAllSeen([]);
      verifyNever(() => client.from(any()));
    });

    test('calls update with seen_at timestamp and inFilter', () async {
      final fb = mockUpdate(client, table: 'ingredient_suggestions');
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.markAllSeen(['sug-1', 'sug-2']);

      verify(
        () => client
            .from('ingredient_suggestions')
            .update(any(that: containsPair('seen_at', isA<String>()))),
      ).called(1);
      verify(() => fb.inFilter('id', ['sug-1', 'sug-2'])).called(1);
    });
  });

  group('IngredientService.dismissSuggestions', () {
    test('returns early without DB call when ids is empty', () async {
      await service.dismissSuggestions([]);
      verifyNever(() => client.from(any()));
    });

    test('calls update with dismissed_at timestamp and inFilter', () async {
      final fb = mockUpdate(client, table: 'ingredient_suggestions');
      when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
      _stubFilterFuture(fb);

      await service.dismissSuggestions(['sug-1']);

      verify(
        () => client
            .from('ingredient_suggestions')
            .update(any(that: containsPair('dismissed_at', isA<String>()))),
      ).called(1);
      verify(() => fb.inFilter('id', ['sug-1'])).called(1);
    });
  });

  group('IngredientService.fetchNewCount', () {
    test('returns count of unseen and undismissed suggestions', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredient_suggestions',
        rows: [
          {'id': 'sug-1'},
          {'id': 'sug-2'},
          {'id': 'sug-3'},
        ],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);

      final count = await service.fetchNewCount(testUserId);

      expect(count, 3);
    });

    test('filters by user_id, seen_at null, and dismissed_at null', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredient_suggestions',
        rows: [],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);

      await service.fetchNewCount(testUserId);

      verify(() => fb.eq('user_id', testUserId)).called(1);
      verify(() => fb.isFilter('seen_at', null)).called(1);
      verify(() => fb.isFilter('dismissed_at', null)).called(1);
    });

    test('returns 0 when no unseen suggestions', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredient_suggestions',
        rows: [],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);

      final count = await service.fetchNewCount(testUserId);

      expect(count, 0);
    });
  });
}

/// Transform builder whose `range` returns successive pages and records the
/// requested ranges.
class _PagedTransform extends MockPostgrestTransformBuilder {
  _PagedTransform(this._pages);

  final List<List<Map<String, dynamic>>> _pages;
  final ranges = <(int, int)>[];

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    ranges.add((from, to));
    final i = ranges.length - 1;
    final page = i < _pages.length ? _pages[i] : <Map<String, dynamic>>[];
    return _SettledTransform(Future.value(page));
  }
}

class _SettledTransform extends MockPostgrestTransformBuilder {
  _SettledTransform(this._future);

  final Future<PostgrestList> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => _future.then(onValue, onError: onError);
}
