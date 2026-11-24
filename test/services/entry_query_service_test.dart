import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/utils/wall_clock.dart';

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

/// Transform builder whose `range` returns successive pages and records the
/// requested ranges, and the orders added after the first one.
class _PagedTransform extends MockPostgrestTransformBuilder {
  _PagedTransform(this._pages);

  final List<List<Map<String, dynamic>>> _pages;
  final ranges = <(int, int)>[];
  final orders = <(String, {bool ascending})>[];

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    orders.add((column, ascending: ascending));
    return this;
  }

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

/// Transform builder whose `limit` returns [_rows] (or throws) and records
/// the count.
class _LimitTransform extends MockPostgrestTransformBuilder {
  _LimitTransform(this._rows);

  final List<Map<String, dynamic>> _rows;
  final limits = <int>[];

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) {
    limits.add(count);
    return _SettledTransform(Future.value(_rows));
  }
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

      // Local midnights, sent as the wall clock in the UTC slot.
      const expectedStart = '2026-03-25T00:00:00.000Z';
      const expectedEnd = '2026-03-26T00:00:00.000Z';

      await service.fetchEntriesForDateRange(
        userId: testUserId,
        date: testDate,
      );

      verify(() => meal.gte('tracked_at', expectedStart)).called(1);
      verify(() => meal.lt('tracked_at', expectedEnd)).called(1);
    });

    // Under TZ=Europe/Vienna: 25 Oct 2026 has 25 hours, 29 Mar 23.
    for (final (day, start, end) in [
      (
        DateTime(2026, 10, 25, 12),
        '2026-10-25T00:00:00.000Z',
        '2026-10-26T00:00:00.000Z',
      ),
      (
        DateTime(2026, 3, 29, 12),
        '2026-03-29T00:00:00.000Z',
        '2026-03-30T00:00:00.000Z',
      ),
    ]) {
      test('a DST switch day ($start) ends at the next midnight', () async {
        final filters = _setupAllTables(client);
        final meal = filters[0];

        await service.fetchEntriesForDateRange(userId: testUserId, date: day);

        verify(() => meal.gte('tracked_at', start)).called(1);
        verify(() => meal.lt('tracked_at', end)).called(1);
      });
    }

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

  group('EntryQueryService.fetchLatestBefore', () {
    final before = DateTime(2026, 11, 23);
    const tables = ['meal_entries', 'gut_feeling_entries', 'drink_entries'];

    ({
      Map<String, SettlableFilterBuilder> filters,
      Map<String, _LimitTransform> limited,
    })
    setUpTables(Map<String, List<Map<String, dynamic>>> rows) {
      final filters = <String, SettlableFilterBuilder>{};
      final limited = <String, _LimitTransform>{};
      for (final t in tables) {
        final qb = MockSupabaseQueryBuilder();
        final f = SettlableFilterBuilder(
          Future.value(<Map<String, dynamic>>[]),
        );
        final l = _LimitTransform(rows[t] ?? []);
        when(() => client.from(t)).thenAnswer((_) => qb);
        when(() => qb.select(any())).thenAnswer((_) => f);
        when(() => f.eq(any(), any())).thenAnswer((_) => f);
        when(() => f.lt(any(), any())).thenAnswer((_) => f);
        when(
          () => f.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer((_) => l);
        filters[t] = f;
        limited[t] = l;
      }
      return (filters: filters, limited: limited);
    }

    test(
      'selects tracked_at before the moment, newest first, one row',
      () async {
        final s = setUpTables({});

        await service.fetchLatestBefore(userId: testUserId, before: before);

        for (final t in tables) {
          verify(() => s.filters[t]!.eq('user_id', testUserId)).called(1);
          verify(
            () => s.filters[t]!.lt('tracked_at', '2026-11-23T00:00:00.000Z'),
          ).called(1);
          verify(
            () => s.filters[t]!.order('tracked_at', ascending: false),
          ).called(1);
          expect(s.limited[t]!.limits, [1]);
        }
        verifyNever(() => client.from('toilet_entries'));
      },
    );

    test('maps each table\'s row, null without one', () async {
      setUpTables({
        // As PostgREST sends them: the wall clock in the UTC slot.
        'meal_entries': [
          {'tracked_at': '2026-11-22T19:00:00+00:00'},
        ],
        'drink_entries': [
          {'tracked_at': '2026-11-22T21:00:00+00:00'},
        ],
      });

      final latest = await service.fetchLatestBefore(
        userId: testUserId,
        before: before,
      );

      expect(latest.meal, DateTime(2026, 11, 22, 19));
      expect(latest.drink, DateTime(2026, 11, 22, 21));
      expect(latest.gutFeeling, isNull);
    });

    test('rethrows', () async {
      final qb = MockSupabaseQueryBuilder();
      when(() => client.from('meal_entries')).thenAnswer((_) => qb);
      when(() => qb.select(any())).thenThrow(Exception('db error'));
      for (final t in ['gut_feeling_entries', 'drink_entries']) {
        final q = MockSupabaseQueryBuilder();
        when(() => client.from(t)).thenAnswer((_) => q);
        when(() => q.select(any())).thenThrow(Exception('db error'));
      }

      await expectLater(
        service.fetchLatestBefore(userId: testUserId, before: before),
        throwsException,
      );
    });

    test('LatestEntries has value equality', () {
      expect(
        LatestEntries(meal: before),
        LatestEntries(meal: DateTime(2026, 11, 23)),
      );
      expect(LatestEntries(meal: before), isNot(const LatestEntries()));
      expect(
        LatestEntries(meal: before).hashCode,
        LatestEntries(meal: DateTime(2026, 11, 23)).hashCode,
      );
    });
  });

  group('EntryQueryService.fetchTrackedAtSince', () {
    final since = DateTime(2026, 3, 1);

    test('selects tracked_at with user and gte filter on all tables', () async {
      final tables = [
        'meal_entries',
        'toilet_entries',
        'gut_feeling_entries',
        'drink_entries',
      ];
      final builders = <String, MockSupabaseQueryBuilder>{};
      final filters = <String, SettlableFilterBuilder>{};
      for (final t in tables) {
        final qb = MockSupabaseQueryBuilder();
        final f = SettlableFilterBuilder(
          Future.value(<Map<String, dynamic>>[]),
        );
        when(() => client.from(t)).thenAnswer((_) => qb);
        when(() => qb.select(any())).thenAnswer((_) => f);
        when(() => f.eq(any(), any())).thenAnswer((_) => f);
        when(() => f.gte(any(), any())).thenAnswer((_) => f);
        when(
          () => f.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer(
          (_) => _PagedTransform([
            [
              {'tracked_at': '2026-03-25T12:00:00.000Z'},
            ],
          ]),
        );
        builders[t] = qb;
        filters[t] = f;
      }

      final result = await service.fetchTrackedAtSince(
        userId: testUserId,
        since: since,
      );

      expect(result, hasLength(4));
      expect(result.first, DateTime(2026, 3, 25, 12));
      for (final t in tables) {
        verify(() => builders[t]!.select('tracked_at')).called(1);
        verify(() => filters[t]!.eq('user_id', testUserId)).called(1);
        verify(
          () => filters[t]!.gte('tracked_at', '2026-03-01T00:00:00.000Z'),
        ).called(1);
      }
    });

    test('with until, also filters lt until on all tables', () async {
      final until = DateTime(2026, 3, 20);
      final filters = <SettlableFilterBuilder>[];
      for (final t in [
        'meal_entries',
        'toilet_entries',
        'gut_feeling_entries',
        'drink_entries',
      ]) {
        final qb = MockSupabaseQueryBuilder();
        final f = SettlableFilterBuilder(
          Future.value(<Map<String, dynamic>>[]),
        );
        when(() => client.from(t)).thenAnswer((_) => qb);
        when(() => qb.select(any())).thenAnswer((_) => f);
        when(() => f.eq(any(), any())).thenAnswer((_) => f);
        when(() => f.gte(any(), any())).thenAnswer((_) => f);
        when(() => f.lt(any(), any())).thenAnswer((_) => f);
        when(
          () => f.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer((_) => _PagedTransform([<Map<String, dynamic>>[]]));
        filters.add(f);
      }

      await service.fetchTrackedAtSince(
        userId: testUserId,
        since: since,
        until: until,
      );

      for (final f in filters) {
        verify(() => f.gte('tracked_at', '2026-03-01T00:00:00.000Z')).called(1);
        verify(() => f.lt('tracked_at', '2026-03-20T00:00:00.000Z')).called(1);
      }
    });

    test('paginates a table until a short page is returned', () async {
      final fullPage = List.generate(
        EntryQueryService.trackedAtPageSize,
        (_) => {'tracked_at': '2026-03-25T12:00:00.000Z'},
      );
      final shortPage = [
        {'tracked_at': '2026-03-24T12:00:00.000Z'},
      ];
      _PagedTransform? meals;
      for (final t in [
        'meal_entries',
        'toilet_entries',
        'gut_feeling_entries',
        'drink_entries',
      ]) {
        final qb = MockSupabaseQueryBuilder();
        final f = SettlableFilterBuilder(
          Future.value(<Map<String, dynamic>>[]),
        );
        final paged = _PagedTransform(
          t == 'meal_entries'
              ? [fullPage, shortPage]
              : [<Map<String, dynamic>>[]],
        );
        if (t == 'meal_entries') meals = paged;
        when(() => client.from(t)).thenAnswer((_) => qb);
        when(() => qb.select(any())).thenAnswer((_) => f);
        when(() => f.eq(any(), any())).thenAnswer((_) => f);
        when(() => f.gte(any(), any())).thenAnswer((_) => f);
        when(
          () => f.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer((_) => paged);
      }

      final result = await service.fetchTrackedAtSince(
        userId: testUserId,
        since: since,
      );

      expect(result, hasLength(EntryQueryService.trackedAtPageSize + 1));
      expect(meals!.ranges, [(0, 999), (1000, 1999)]);
    });

    test(
      'pages in a total order: by tracked_at, then by the unique id',
      () async {
        final filters = <String, SettlableFilterBuilder>{};
        final paged = <String, _PagedTransform>{};
        for (final t in [
          'meal_entries',
          'toilet_entries',
          'gut_feeling_entries',
          'drink_entries',
        ]) {
          final qb = MockSupabaseQueryBuilder();
          final f = SettlableFilterBuilder(
            Future.value(<Map<String, dynamic>>[]),
          );
          final p = _PagedTransform([<Map<String, dynamic>>[]]);
          when(() => client.from(t)).thenAnswer((_) => qb);
          when(() => qb.select(any())).thenAnswer((_) => f);
          when(() => f.eq(any(), any())).thenAnswer((_) => f);
          when(() => f.gte(any(), any())).thenAnswer((_) => f);
          when(
            () => f.order(any(), ascending: any(named: 'ascending')),
          ).thenAnswer((_) => p);
          filters[t] = f;
          paged[t] = p;
        }

        await service.fetchTrackedAtSince(userId: testUserId, since: since);

        for (final t in filters.keys) {
          verify(
            () => filters[t]!.order('tracked_at', ascending: false),
          ).called(1);
          expect(paged[t]!.orders, [('id', ascending: false)], reason: t);
        }
      },
    );

    test('with tables, queries only those tables', () async {
      final qb = MockSupabaseQueryBuilder();
      final f = SettlableFilterBuilder(Future.value(<Map<String, dynamic>>[]));
      when(() => client.from('gut_feeling_entries')).thenAnswer((_) => qb);
      when(() => qb.select(any())).thenAnswer((_) => f);
      when(() => f.eq(any(), any())).thenAnswer((_) => f);
      when(() => f.gte(any(), any())).thenAnswer((_) => f);
      when(() => f.order(any(), ascending: any(named: 'ascending'))).thenAnswer(
        (_) => _PagedTransform([
          [
            {'tracked_at': '2026-03-25T12:00:00.000Z'},
            {'tracked_at': '2026-03-24T12:00:00.000Z'},
          ],
        ]),
      );

      final result = await service.fetchTrackedAtSince(
        userId: testUserId,
        since: since,
        tables: const ['gut_feeling_entries'],
      );

      expect(result, hasLength(2));
      verify(() => client.from('gut_feeling_entries')).called(1);
      verifyNoMoreInteractions(client);
    });

    test('rethrows exceptions from supabase', () async {
      final qb = MockSupabaseQueryBuilder();
      when(() => client.from(any())).thenAnswer((_) => qb);
      when(() => qb.select(any())).thenThrow(Exception('db error'));

      await expectLater(
        service.fetchTrackedAtSince(userId: testUserId, since: since),
        throwsException,
      );
    });
  });

  group('EntryQueryService.fetchInsightSource', () {
    final since = DateTime(2026, 10, 25);
    final mealsSince = DateTime(2026, 10, 24);
    const tables = [
      'meal_entries',
      'toilet_entries',
      'gut_feeling_entries',
      'drink_entries',
    ];

    Map<String, dynamic> gutRow(String at) => {..._gutRow(), 'tracked_at': at};

    /// Mocks every table; [pages] gives each table's pages.
    (
      Map<String, MockSupabaseQueryBuilder>,
      Map<String, SettlableFilterBuilder>,
      Map<String, _PagedTransform>,
    )
    mockTables(Map<String, List<List<Map<String, dynamic>>>> pages) {
      final builders = <String, MockSupabaseQueryBuilder>{};
      final filters = <String, SettlableFilterBuilder>{};
      final paged = <String, _PagedTransform>{};
      for (final t in tables) {
        final qb = MockSupabaseQueryBuilder();
        final f = SettlableFilterBuilder(
          Future.value(<Map<String, dynamic>>[]),
        );
        final p = _PagedTransform(pages[t] ?? [<Map<String, dynamic>>[]]);
        when(() => client.from(t)).thenAnswer((_) => qb);
        when(() => qb.select(any())).thenAnswer((_) => f);
        when(() => f.eq(any(), any())).thenAnswer((_) => f);
        when(() => f.gte(any(), any())).thenAnswer((_) => f);
        when(
          () => f.order(any(), ascending: any(named: 'ascending')),
        ).thenAnswer((_) => p);
        builders[t] = qb;
        filters[t] = f;
        paged[t] = p;
      }
      return (builders, filters, paged);
    }

    test(
      'fetchInsightSource selects each table once with its columns',
      () async {
        final (builders, filters, _) = mockTables({});

        await service.fetchInsightSource(
          userId: testUserId,
          since: since,
          mealsSince: mealsSince,
        );

        verify(
          () => builders['meal_entries']!.select('tracked_at, ingredients'),
        ).called(1);
        verify(() => builders['gut_feeling_entries']!.select('*')).called(1);
        verify(
          () => builders['toilet_entries']!.select('tracked_at'),
        ).called(1);
        verify(() => builders['drink_entries']!.select('tracked_at')).called(1);
        for (final t in tables) {
          verify(() => filters[t]!.eq('user_id', testUserId)).called(1);
          verify(() => filters[t]!.gte('tracked_at', any())).called(1);
        }
      },
    );

    test('fetches meals 24 h before the window', () async {
      final (_, filters, _) = mockTables({});

      await service.fetchInsightSource(
        userId: testUserId,
        since: since,
        mealsSince: mealsSince,
      );

      // Local times, sent as the wall clock in the UTC slot.
      verify(
        () => filters['meal_entries']!.gte(
          'tracked_at',
          wallClockToWire(mealsSince),
        ),
      ).called(1);
      for (final t in tables.where((t) => t != 'meal_entries')) {
        verify(
          () => filters[t]!.gte('tracked_at', wallClockToWire(since)),
        ).called(1);
      }
    });

    test('paginates every table', () async {
      List<Map<String, dynamic>> full(Map<String, dynamic> row) =>
          List.generate(EntryQueryService.trackedAtPageSize, (_) => row);
      final short = [
        for (final r in [1, 2, 3])
          {'tracked_at': '2026-11-0${r}T12:00:00.000Z'},
      ];
      final fullRow = {'tracked_at': '2026-11-10T12:00:00.000Z'};
      final gutShort = [
        for (final r in [1, 2, 3]) gutRow('2026-11-0${r}T12:00:00.000Z'),
      ];
      final (_, _, paged) = mockTables({
        'meal_entries': [full(fullRow), short],
        'toilet_entries': [full(fullRow), short],
        'drink_entries': [full(fullRow), short],
        'gut_feeling_entries': [
          full(gutRow('2026-11-10T12:00:00.000Z')),
          gutShort,
        ],
      });

      final result = await service.fetchInsightSource(
        userId: testUserId,
        since: since,
        mealsSince: mealsSince,
      );

      expect(result.meals, hasLength(1003));
      expect(result.gutFeelings, hasLength(1003));
      expect(result.activityTimes, hasLength(4 * 1003));
      for (final t in tables) {
        expect(paged[t]!.ranges, [(0, 999), (1000, 1999)]);
      }
    });

    test('pages every table by tracked_at, then by the unique id', () async {
      final (_, filters, paged) = mockTables({});

      await service.fetchInsightSource(
        userId: testUserId,
        since: since,
        mealsSince: mealsSince,
      );

      for (final t in tables) {
        verify(
          () => filters[t]!.order('tracked_at', ascending: false),
        ).called(1);
        expect(paged[t]!.orders, [('id', ascending: false)], reason: t);
      }
    });

    test('meals before since are not activity', () async {
      // Wall-clock times; `since` is the night the clocks go back, where
      // adding a Duration lands on an ambiguous hour.
      final early = DateTime(2026, 10, 24, 22);
      final inside = DateTime(2026, 10, 25, 3);
      mockTables({
        'meal_entries': [
          [
            {
              'tracked_at': wallClockToWire(inside),
              'ingredients': ['Reis'],
            },
            {'tracked_at': wallClockToWire(early), 'ingredients': null},
          ],
        ],
      });

      final result = await service.fetchInsightSource(
        userId: testUserId,
        since: since,
        mealsSince: mealsSince,
      );

      expect(result.meals.map((m) => m.trackedAt), [inside, early]);
      expect(result.meals.first.ingredients, ['Reis']);
      expect(result.meals.last.ingredients, isEmpty);
      expect(result.activityTimes, [inside]);
    });

    test('activity holds the wall-clock times of all four tables', () async {
      mockTables({
        'meal_entries': [
          [
            {'tracked_at': '2026-11-01T08:00:00.000Z', 'ingredients': []},
          ],
        ],
        'toilet_entries': [
          [
            {'tracked_at': '2026-11-02T08:00:00.000Z'},
          ],
        ],
        'gut_feeling_entries': [
          [gutRow('2026-11-03T08:00:00.000Z')],
        ],
        'drink_entries': [
          [
            {'tracked_at': '2026-11-04T08:00:00.000Z'},
          ],
        ],
      });

      final result = await service.fetchInsightSource(
        userId: testUserId,
        since: since,
        mealsSince: mealsSince,
      );

      expect(result.activityTimes.toSet(), {
        for (final d in [1, 2, 3, 4]) DateTime(2026, 11, d, 8),
      });
      expect(result.gutFeelings.single.trackedAt, DateTime(2026, 11, 3, 8));
    });
  });
}
