import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/drink_service.dart';

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

Map<String, dynamic> _drinkRow({
  String id = 'water-id',
  String name = 'Wasser',
  String? addedByUserId,
}) => {'id': id, 'name': name, 'added_by_user_id': addedByUserId};

void main() {
  late MockSupabaseClient client;
  late DrinkService service;

  setUp(() {
    client = MockSupabaseClient();
    service = DrinkService(client);
  });

  group('DrinkService.fetchAll', () {
    test('returns list of Drink from DB rows', () async {
      final fb = mockSelectRows(
        client,
        table: 'drinks',
        rows: [
          _drinkRow(),
          _drinkRow(id: 'juice-id', name: 'Saft'),
        ],
      );
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchAll();

      expect(result, hasLength(2));
      expect(result.first.id, 'water-id');
      expect(result.first.name, 'Wasser');
      expect(result[1].name, 'Saft');
    });

    test('returns empty list when no drinks exist', () async {
      final fb = mockSelectRows(client, table: 'drinks', rows: []);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      final result = await service.fetchAll();

      expect(result, isEmpty);
    });

    test('orders by name', () async {
      final fb = mockSelectRows(client, table: 'drinks', rows: []);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);

      await service.fetchAll();

      verify(
        () => fb.order('name', ascending: any(named: 'ascending')),
      ).called(1);
    });
  });

  group('DrinkService.fetchTodayTotal', () {
    test('sums amount_ml values for today', () async {
      final fb = mockSelectRows(
        client,
        table: 'drink_entries',
        rows: [
          {'amount_ml': 250},
          {'amount_ml': 500},
        ],
      );
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
      when(() => fb.lt(any(), any())).thenAnswer((_) => fb);

      final total = await service.fetchTodayTotal(testUserId);

      expect(total, 750);
    });

    test('returns 0 for empty results', () async {
      final fb = mockSelectRows(client, table: 'drink_entries', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
      when(() => fb.lt(any(), any())).thenAnswer((_) => fb);

      final total = await service.fetchTodayTotal(testUserId);

      expect(total, 0);
    });

    test('filters by user_id', () async {
      final fb = mockSelectRows(client, table: 'drink_entries', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
      when(() => fb.lt(any(), any())).thenAnswer((_) => fb);

      await service.fetchTodayTotal(testUserId);

      verify(() => fb.eq('user_id', testUserId)).called(1);
    });
  });

  group('DrinkService.fetchRecentDrinkIds', () {
    test('deduplicates drink_ids and limits to 10', () async {
      // Provide 12 rows: first 10 unique IDs + 2 duplicates of id-1 and id-2
      final rows = [
        for (var i = 1; i <= 10; i++) {'drink_id': 'id-$i'},
        {'drink_id': 'id-1'},
        {'drink_id': 'id-2'},
      ];
      final fb = mockSelectRows(client, table: 'drink_entries', rows: rows);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);

      final result = await service.fetchRecentDrinkIds(testUserId);

      expect(result, hasLength(10));
      // duplicates removed — still only 10 unique IDs
      expect(result.toSet().length, 10);
    });

    test(
      'deduplicates repeated drink IDs preserving first occurrence',
      () async {
        final fb = mockSelectRows(
          client,
          table: 'drink_entries',
          rows: [
            {'drink_id': 'water-id'},
            {'drink_id': 'juice-id'},
            {'drink_id': 'water-id'},
            {'drink_id': 'tea-id'},
          ],
        );
        when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
        when(
          () => fb.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer((_) => fb);
        when(() => fb.limit(any())).thenAnswer((_) => fb);

        final result = await service.fetchRecentDrinkIds(testUserId);

        expect(result, ['water-id', 'juice-id', 'tea-id']);
      },
    );

    test('fetches with limit 20 before deduplication', () async {
      final fb = mockSelectRows(client, table: 'drink_entries', rows: []);
      when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
      when(
        () => fb.order(any(), ascending: any(named: 'ascending')),
      ).thenAnswer((_) => fb);
      when(() => fb.limit(any())).thenAnswer((_) => fb);

      await service.fetchRecentDrinkIds(testUserId);

      verify(() => fb.limit(20)).called(1);
    });
  });

  group('DrinkService.insertDrink', () {
    test('inserts drink with name and userId, returns Drink', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      final filterBuilder = MockPostgrestFilterBuilder();
      final transformBuilder = MockPostgrestTransformBuilder();
      final row = _drinkRow(addedByUserId: testUserId);
      final settled = settleMap(row);

      when(() => client.from('drinks')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.insert(any())).thenAnswer((_) => filterBuilder);
      when(
        () => filterBuilder.select(any()),
      ).thenAnswer((_) => transformBuilder);
      when(() => transformBuilder.single()).thenAnswer((_) => settled);

      final result = await service.insertDrink('Wasser', userId: testUserId);

      expect(result.name, 'Wasser');
      expect(result.addedByUserId, testUserId);
    });

    test('passes added_by_user_id in insert payload', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      final filterBuilder = MockPostgrestFilterBuilder();
      final transformBuilder = MockPostgrestTransformBuilder();
      final settled = settleMap(_drinkRow(addedByUserId: testUserId));

      when(() => client.from('drinks')).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.insert(any())).thenAnswer((_) => filterBuilder);
      when(
        () => filterBuilder.select(any()),
      ).thenAnswer((_) => transformBuilder);
      when(() => transformBuilder.single()).thenAnswer((_) => settled);

      await service.insertDrink('Wasser', userId: testUserId);

      final captured =
          verify(() => queryBuilder.insert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['added_by_user_id'], testUserId);
      expect(captured['name'], 'Wasser');
      expect(captured['added_via'], 'user');
    });
  });

  group('DrinkService.deleteDrink', () {
    test('deletes drink_entries first, then drinks record', () async {
      // Separate filter builders for the two tables
      final entriesQb = MockSupabaseQueryBuilder();
      final entriesFb = MockPostgrestFilterBuilder();
      final drinksQb = MockSupabaseQueryBuilder();
      final drinksFb = MockPostgrestFilterBuilder();

      when(() => client.from('drink_entries')).thenAnswer((_) => entriesQb);
      when(() => entriesQb.delete()).thenAnswer((_) => entriesFb);
      when(() => entriesFb.eq(any(), any())).thenAnswer((_) => entriesFb);
      _stubFilterFuture(entriesFb);

      when(() => client.from('drinks')).thenAnswer((_) => drinksQb);
      when(() => drinksQb.delete()).thenAnswer((_) => drinksFb);
      when(() => drinksFb.eq(any(), any())).thenAnswer((_) => drinksFb);
      _stubFilterFuture(drinksFb);

      await service.deleteDrink('water-id');

      verify(() => entriesFb.eq('drink_id', 'water-id')).called(1);
      verify(() => drinksFb.eq('id', 'water-id')).called(1);
    });
  });
}
