import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/services/entry_query_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

// Raw DB rows for each entry type.
Map<String, dynamic> _mealRow() => {
  'id': 'meal-1',
  'user_id': testUserId,
  'tracked_at': '2026-03-25T12:00:00.000',
  'title': 'Testmahlzeit',
  'ingredients': <dynamic>[],
  'image_url': null,
  'notes': null,
  'created_at': null,
};

Map<String, dynamic> _toiletRow() => {
  'id': 'toilet-1',
  'user_id': testUserId,
  'tracked_at': '2026-03-25T14:00:00.000',
  'stool_type': 3,
  'notes': null,
  'created_at': null,
};

Map<String, dynamic> _gutRow() => {
  'id': 'gut-1',
  'user_id': testUserId,
  'tracked_at': '2026-03-25T16:00:00.000',
  'bloating': 2,
  'gas': 1,
  'cramps': 0,
  'fullness': 2,
  'stress': null,
  'happiness': null,
  'energy': null,
  'focus': null,
  'body_feel': null,
  'notes': null,
  'created_at': null,
};

Map<String, dynamic> _drinkRow() => {
  'id': 'drink-entry-1',
  'user_id': testUserId,
  'tracked_at': '2026-03-25T10:00:00.000',
  'drink_id': 'water-id',
  'amount_ml': 250,
  'notes': null,
  'created_at': null,
  'drinks': {'name': 'Wasser'},
};

/// Sets up all four table mocks using [mockSelectRows] so that
/// `Future.wait` resolves correctly.
/// Returns the four filter builders in order: meal, toilet, gut, drink.
List<MockPostgrestFilterBuilder> _setupAllTables(
  MockSupabaseClient client, {
  bool withRows = true,
}) {
  final meal = mockSelectRows(
    client,
    table: 'meal_entries',
    rows: withRows ? [_mealRow()] : [],
  );
  final toilet = mockSelectRows(
    client,
    table: 'toilet_entries',
    rows: withRows ? [_toiletRow()] : [],
  );
  final gut = mockSelectRows(
    client,
    table: 'gut_feeling_entries',
    rows: withRows ? [_gutRow()] : [],
  );
  final drink = mockSelectRows(
    client,
    table: 'drink_entries',
    rows: withRows ? [_drinkRow()] : [],
  );

  for (final f in [meal, toilet, gut, drink]) {
    when(() => f.eq(any(), any())).thenAnswer((_) => f);
    when(() => f.gte(any(), any())).thenAnswer((_) => f);
    when(() => f.lt(any(), any())).thenAnswer((_) => f);
    when(
      () => f.order(any(), ascending: any(named: 'ascending')),
    ).thenAnswer((_) => f);
  }

  return [meal, toilet, gut, drink];
}

void main() {
  late MockSupabaseClient client;
  late EntryQueryService service;

  final testDate = DateTime(2026, 3, 25);

  setUp(() {
    client = MockSupabaseClient();
    service = EntryQueryService(client);
  });

  group('EntryQueryService.fetchEntriesForDateRange', () {
    test('returns EntryQueryResult with all 4 entry types', () async {
      _setupAllTables(client);

      final result = await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
      );

      expect(result.meals, hasLength(1));
      expect(result.meals.first.id, 'meal-1');
      expect(result.toiletEntries, hasLength(1));
      expect(result.toiletEntries.first.id, 'toilet-1');
      expect(result.gutFeelings, hasLength(1));
      expect(result.gutFeelings.first.id, 'gut-1');
      expect(result.drinks, hasLength(1));
      expect(result.drinks.first.id, 'drink-entry-1');
    });

    test('maps drink name from nested join data', () async {
      _setupAllTables(client);

      final result = await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
      );

      expect(result.drinks.first.drinkName, 'Wasser');
    });

    test('filters by user_id via eq', () async {
      final filters = _setupAllTables(client);
      final meal = filters[0];

      await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
      );

      verify(() => meal.eq('user_id', testUserId)).called(1);
    });

    test('filters by date range: gte start, lt end', () async {
      final filters = _setupAllTables(client);
      final meal = filters[0];

      final expectedStart = DateTime(2026, 3, 25).toIso8601String();
      final expectedEnd = DateTime(2026, 3, 26).toIso8601String();

      await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
      );

      verify(() => meal.gte('tracked_at', expectedStart)).called(1);
      verify(() => meal.lt('tracked_at', expectedEnd)).called(1);
    });

    test('ordered=true applies .order() on each table', () async {
      final filters = _setupAllTables(client);
      final meal = filters[0];
      final toilet = filters[1];
      final gut = filters[2];
      final drink = filters[3];

      await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
        ordered: true,
      );

      verify(() => meal.order('tracked_at', ascending: false)).called(1);
      verify(() => toilet.order('tracked_at', ascending: false)).called(1);
      verify(() => gut.order('tracked_at', ascending: false)).called(1);
      verify(() => drink.order('tracked_at', ascending: false)).called(1);
    });

    test('ordered=false does not call .order()', () async {
      final filters = _setupAllTables(client, withRows: false);
      final meal = filters[0];

      await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
        ordered: false,
      );

      verifyNever(() => meal.order(any(), ascending: any(named: 'ascending')));
    });

    test('uses provided userId for filtering', () async {
      const customUserId = 'custom-user-99';
      final filters = _setupAllTables(client, withRows: false);
      final meal = filters[0];

      await service.fetchEntriesForDateRange(
        userId: customUserId,
        date: testDate,
      );

      verify(() => meal.eq('user_id', customUserId)).called(1);
    });

    test('rethrows exceptions from supabase', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      when(() => client.from('meal_entries')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select(any())).thenThrow(Exception('db error'));

      await expectLater(
        service.fetchEntriesForDateRange(userId: testUserId, date: testDate),
        throwsException,
      );
    });
  });
}
