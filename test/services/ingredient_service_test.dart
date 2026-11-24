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
    test('returns early without inserting when userId is null', () async {
      // No mocks set up — if any DB call were made, the test would throw.
      await service.insertIfNew('Zwiebel', userId: null);
      verifyNever(() => client.from(any()));
    });

    test('skips insert when matching ingredient already exists', () async {
      // Use a single queryBuilder so we can verify insert was never called on it.
      final queryBuilder = MockSupabaseQueryBuilder();
      final selectFb = SettlableFilterBuilder(
        Future.value([
          {'id': 'ing-existing'},
        ]),
      );

      when(() => client.from('ingredients')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select(any())).thenAnswer((_) => selectFb);
      when(() => selectFb.ilike(any(), any())).thenAnswer((_) => selectFb);
      when(() => selectFb.limit(any())).thenAnswer((_) => selectFb);

      await service.insertIfNew('Zwiebel', userId: testUserId);

      // Insert should NOT have been called on the queryBuilder
      verifyNever(() => queryBuilder.insert(any()));
    });

    test('inserts when no existing ingredient found', () async {
      // Use a single queryBuilder for both select (first call) and insert (second call).
      final queryBuilder = MockSupabaseQueryBuilder();
      final selectFb = SettlableFilterBuilder(Future.value([]));
      final insertFb = MockPostgrestFilterBuilder();

      when(() => client.from('ingredients')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select(any())).thenAnswer((_) => selectFb);
      when(() => selectFb.ilike(any(), any())).thenAnswer((_) => selectFb);
      when(() => selectFb.limit(any())).thenAnswer((_) => selectFb);
      when(() => queryBuilder.insert(any())).thenAnswer((_) => insertFb);
      _stubFilterFuture(insertFb);

      await service.insertIfNew('Zwiebel', userId: testUserId);

      final captured =
          verify(() => queryBuilder.insert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['name'], 'Zwiebel');
      expect(captured['added_by_user_id'], testUserId);
      expect(captured['added_via'], 'user');
    });
  });

  group('IngredientService.insertIfNew on a name the user cannot see', () {
    // The catalog's unique name can belong to a row the user's row level
    // security hides (another user's, or an AI-detected one): the insert
    // then fails with 23505, although the ingredient exists.
    void stubInsertFailing(Object error) {
      final queryBuilder = MockSupabaseQueryBuilder();
      final selectFb = SettlableFilterBuilder(Future.value([]));
      final insertFb = SettlableFilterBuilder(Future.error(error));
      when(() => client.from('ingredients')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select(any())).thenAnswer((_) => selectFb);
      when(() => selectFb.ilike(any(), any())).thenAnswer((_) => selectFb);
      when(() => selectFb.limit(any())).thenAnswer((_) => selectFb);
      when(() => queryBuilder.insert(any())).thenAnswer((_) => insertFb);
    }

    test('a duplicate name counts as already there', () async {
      stubInsertFailing(
        const PostgrestException(
          message:
              'duplicate key value violates unique constraint '
              '"ingredients_name_key"',
          code: '23505',
        ),
      );

      await expectLater(
        service.insertIfNew('Haferflocken', userId: testUserId),
        completes,
      );
    });

    test('other errors still surface', () async {
      stubInsertFailing(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );

      await expectLater(
        service.insertIfNew('Haferflocken', userId: testUserId),
        throwsA(isA<PostgrestException>()),
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

      final result = await service.fetchReplacements(['sug-1', 'sug-2']);

      expect(result, hasLength(1));
      verify(() => fb.inFilter('suggestion_id', ['sug-1', 'sug-2'])).called(1);
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
