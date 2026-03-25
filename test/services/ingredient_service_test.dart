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
    test('returns list of IngredientSuggestion from DB rows', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredients',
        rows: [
          {'id': 'ing-1', 'name': 'Zwiebel', 'added_by_user_id': 'other-user'},
          {'id': 'ing-2', 'name': 'Knoblauch', 'added_by_user_id': testUserId},
        ],
      );
      when(() => fb.ilike(any(), any())).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);

      final result = await service.search('knob', userId: testUserId);

      expect(result, hasLength(2));
      expect(result[0].id, 'ing-1');
      expect(result[0].name, 'Zwiebel');
      expect(result[0].isOwn, isFalse);
    });

    test('sets isOwn=true when added_by_user_id matches userId', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredients',
        rows: [
          {'id': 'ing-2', 'name': 'Knoblauch', 'added_by_user_id': testUserId},
        ],
      );
      when(() => fb.ilike(any(), any())).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);

      final result = await service.search('knob', userId: testUserId);

      expect(result.first.isOwn, isTrue);
    });

    test('sets isOwn=false when userId is null', () async {
      final fb = mockSelectRows(
        client,
        table: 'ingredients',
        rows: [
          {'id': 'ing-1', 'name': 'Zwiebel', 'added_by_user_id': testUserId},
        ],
      );
      when(() => fb.ilike(any(), any())).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);

      final result = await service.search('zwi', userId: null);

      // null userId never matches added_by_user_id
      expect(result.first.isOwn, isFalse);
    });

    test('passes ilike filter with query wrapped in %', () async {
      final fb = mockSelectRows(client, table: 'ingredients', rows: []);
      when(() => fb.ilike(any(), any())).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);

      await service.search('abc', userId: testUserId);

      verify(() => fb.ilike('name', '%abc%')).called(1);
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
