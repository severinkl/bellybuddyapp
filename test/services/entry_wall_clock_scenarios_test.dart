import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/buddy/log_moment.dart';
import 'package:belly_buddy/services/buddy/streak_engine.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/services/insights/insights_engine.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/utils/wall_clock.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

// Entry times end to end, from the value PostgREST sends to what the user
// sees. `tracked_at` holds the wall clock in the UTC slot, so 23:30 arrives
// as `…T23:30:00+00:00`. Meaningful under `TZ=Europe/Vienna` (CI runs these
// tests in it); under UTC a wall clock and an instant look alike.

/// [wallClock] (`2026-11-23T23:30`) as PostgREST sends it.
String _wire(String wallClock) => '$wallClock:00+00:00';

MealEntry _meal(String at) => MealEntry.fromJson({
  'id': 'm$at',
  'title': 'Essen',
  'tracked_at': _wire(at),
});

DrinkEntry _drink(String at) => DrinkEntry.fromDbRow({
  'id': 'd$at',
  'drink_id': 'water',
  'amount_ml': 250,
  'tracked_at': _wire(at),
  'drinks': {'name': 'Wasser'},
});

GutFeelingEntry _gutFeeling(String at, {int bloating = 1}) =>
    GutFeelingEntry.fromJson({
      'id': 'g$at',
      'bloating': bloating,
      'gas': 0,
      'cramps': 0,
      'fullness': 0,
      'tracked_at': _wire(at),
    });

ToiletEntry _toilet(String at) => ToiletEntry.fromJson({
  'id': 't$at',
  'stool_type': 3,
  'tracked_at': _wire(at),
});

/// A `range` (or `limit`) that answers with one settled page.
class _Page extends MockPostgrestTransformBuilder {
  _Page(this._rows);

  final List<Map<String, dynamic>> _rows;

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
  }) => _Settled(Future.value(from == 0 ? _rows : <Map<String, dynamic>>[]));

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) => _Settled(Future.value(_rows.take(count).toList()));
}

class _Settled extends MockPostgrestTransformBuilder {
  _Settled(this._future);

  final Future<PostgrestList> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => _future.then(onValue, onError: onError);
}

/// Serves [rows] per entry table (none for a table left out); returns
/// each table's filter builder.
Map<String, SettlableFilterBuilder> _serveRows(
  MockSupabaseClient client,
  Map<String, List<Map<String, dynamic>>> rows,
) {
  final filters = <String, SettlableFilterBuilder>{};
  for (final t in entryTableFor.values) {
    final qb = MockSupabaseQueryBuilder();
    final f = SettlableFilterBuilder(Future.value(<Map<String, dynamic>>[]));
    when(() => client.from(t)).thenAnswer((_) => qb);
    when(() => qb.select(any())).thenAnswer((_) => f);
    when(() => f.eq(any(), any())).thenAnswer((_) => f);
    when(() => f.gte(any(), any())).thenAnswer((_) => f);
    when(() => f.lt(any(), any())).thenAnswer((_) => f);
    when(
      () => f.order(any(), ascending: any(named: 'ascending')),
    ).thenAnswer((_) => _Page(rows[t] ?? const []));
    filters[t] = f;
  }
  return filters;
}

/// Serves [wallClocks] (as wire values) from [table] and nothing from the
/// other entry tables; returns each table's filter builder.
Map<String, SettlableFilterBuilder> _serveTrackedAt(
  MockSupabaseClient client,
  List<String> wallClocks, {
  String table = 'meal_entries',
}) => _serveRows(client, {
  table: [
    for (final w in wallClocks) {'tracked_at': _wire(w)},
  ],
});

/// A `gut_feeling_entries` row at [at] whose gut score is [score].
Map<String, dynamic> _gutRow(String at, int score) => {
  'id': 'g$at',
  'tracked_at': _wire(at),
  'bloating': score,
  'gas': score,
  'cramps': score,
  'fullness': score,
};

void main() {
  group('care log (meters, Klo line)', () {
    final day = DateTime(2026, 11, 23);

    test('a 23:30 entry of every kind is logged on its own day', () {
      final now = DateTime(2026, 11, 23, 23, 45);
      final log = CareLog.fromEntries(
        EntriesState(
          day: day,
          meals: [_meal('2026-11-23T23:30')],
          drinks: [_drink('2026-11-23T23:30')],
          gutFeelings: [_gutFeeling('2026-11-23T23:30')],
          toiletEntries: [_toilet('2026-11-23T23:30')],
        ),
        day,
      );

      for (final need in CareNeed.values) {
        expect(
          log.lastAt(need),
          DateTime(2026, 11, 23, 23, 30),
          reason: '$need',
        );
        expect(log.loggedOn(need, now), isTrue, reason: '$need');
      }
      expect(CareCopy.looLine(log, now), 'vor 15 Min');
    });

    test('a drink at 04:38 was „vor 20 Min“ at 04:58, not „um 05:38“', () {
      final today = DateTime(2026, 11, 24);
      final log = CareLog.fromEntries(
        EntriesState(day: today, drinks: [_drink('2026-11-24T04:38')]),
        today,
      );

      expect(
        CareCopy.spoken(CareNeed.drink, log, DateTime(2026, 11, 24, 4, 58)),
        'zuletzt vor 20 Min',
      );
    });

    test('a meter drains from the entry on, not an hour later', () {
      final log = CareLog.fromEntries(
        EntriesState(day: day, drinks: [_drink('2026-11-23T12:00')]),
        day,
      );

      // One awake hour of Trinken's drain from full.
      expect(
        CareMeters.at(log, DateTime(2026, 11, 23, 13)).drink,
        closeTo(
          1 -
              (1 - AppConstants.careMeterFloor) *
                  60 /
                  AppConstants.careDrinkDrain.inMinutes,
          1e-9,
        ),
      );
    });

    test("the day's Bauchgefühl is a bad 23:30 check-in", () {
      final log = CareLog.fromEntries(
        EntriesState(
          day: day,
          gutFeelings: [
            _gutFeeling('2026-11-23T12:00'),
            _gutFeeling('2026-11-23T23:30', bloating: 5),
          ],
        ),
        day,
      );

      expect(log.lastGutFeelingLevel, GutFeelingRatingLevel.schlecht);
    });
  });

  group('meal prompt', () {
    test('a 09:45 breakfast is breakfast: Mittagessen is asked for', () {
      final day = DateTime(2026, 11, 23);
      final log = CareLog.fromEntries(
        EntriesState(
          day: day,
          meals: [_meal('2026-11-23T09:45')],
          drinks: [_drink('2026-11-23T13:30')],
          gutFeelings: [_gutFeeling('2026-11-23T13:30')],
        ),
        day,
      );

      expect(
        nextCareAction(log, DateTime(2026, 11, 23, 13, 45)),
        CareAction.lunch,
      );
    });

    test('in summer (CEST) a 15:15 snack is no dinner', () {
      final day = DateTime(2026, 7, 14);
      final log = CareLog.fromEntries(
        EntriesState(
          day: day,
          meals: [_meal('2026-07-14T15:15')],
          drinks: [_drink('2026-07-14T19:15')],
          gutFeelings: [_gutFeeling('2026-07-14T19:15')],
        ),
        day,
      );

      expect(
        nextCareAction(log, DateTime(2026, 7, 14, 19, 30)),
        CareAction.dinner,
      );
    });
  });

  group('log moment (success page)', () {
    final day = DateTime(2026, 11, 23);

    test('a drink an hour after the last fills from a drained meter', () {
      final now = DateTime(2026, 11, 23, 13);
      final moment = logMomentFor(
        need: CareNeed.drink,
        trackedAt: now,
        care: CareLog.fromEntries(
          EntriesState(day: day, drinks: [_drink('2026-11-23T12:00')]),
          day,
        ),
        now: now,
      );

      expect(moment.from, lessThan(1.0));
      expect(moment.to, 1.0);
    });

    test("the morning's first entry after yesterday's 23:30 one ignites "
        'the day', () {
      final now = DateTime(2026, 11, 23, 8);
      final moment = logMomentFor(
        need: CareNeed.drink,
        trackedAt: now,
        care: CareLog.fromEntries(
          EntriesState(
            day: day,
            latestBefore: LatestEntries(
              drink: wallClockFromWire(_wire('2026-11-22T23:30')),
            ),
          ),
          day,
        ),
        now: now,
        buddy: const BuddyStatus(
          state: BuddyState(),
          hasRow: true,
          streak: 3,
          todayCounted: false,
        ),
      );

      expect(moment.ignitesDay, 4);
    });
  });

  group('Muster (insights)', () {
    late MockSupabaseClient client;
    late EntryRepository repo;
    final now = DateTime(2026, 11, 23, 23, 45);

    setUp(() {
      client = MockSupabaseClient();
      repo = EntryRepository(MockEntryCrudService(), EntryQueryService(client));
    });

    Future<Insights> insights() async => computeInsights(
      await repo.fetchInsightSource(userId: testUserId, now: now),
      now,
    );

    test("a bad 23:30 check-in is today's, on today's calendar day", () async {
      _serveRows(client, {
        'gut_feeling_entries': [_gutRow('2026-11-23T23:30', 5)],
      });

      final result = await insights();

      expect(result.calendar.last.day, DateTime(2026, 11, 23));
      expect(result.calendar.last.dayClass, DayClass.hard);
      expect(
        result.progress,
        const InsightProgress(activeDays: 1, gutFeelingEntries: 1),
      );
    });

    test('a 23:30 check-in the day before the window stays out', () async {
      _serveRows(client, {
        'gut_feeling_entries': [
          _gutRow('2026-10-24T23:30', 5),
          _gutRow('2026-10-25T00:15', 1),
        ],
      });

      final result = await insights();

      expect(result.calendar.first.day, DateTime(2026, 10, 25));
      expect(result.calendar.first.dayClass, DayClass.good);
      expect(result.progress.gutFeelingEntries, 1);
    });

    test('late entries of every kind count, each on its own day', () async {
      _serveRows(client, {
        'meal_entries': [
          {'tracked_at': _wire('2026-11-20T23:30'), 'ingredients': <String>[]},
        ],
        'drink_entries': [
          {'tracked_at': _wire('2026-11-21T23:30')},
        ],
        'toilet_entries': [
          {'tracked_at': _wire('2026-11-22T23:30')},
        ],
        'gut_feeling_entries': [_gutRow('2026-11-23T23:30', 1)],
      });

      expect((await insights()).progress.activeDays, 4);
    });

    test('the window is sent as the wall clock', () async {
      final filters = _serveRows(client, const {});

      await insights();

      expect(
        verify(
          () => filters['meal_entries']!.gte('tracked_at', captureAny()),
        ).captured.single,
        '2026-10-24T00:00:00.000Z',
      );
      for (final t in [
        'gut_feeling_entries',
        'toilet_entries',
        'drink_entries',
      ]) {
        verify(
          () => filters[t]!.gte('tracked_at', '2026-10-25T00:00:00.000Z'),
        ).called(1);
      }
    });
  });

  group('streak (flame)', () {
    late MockSupabaseClient client;
    late EntryRepository repo;

    setUp(() {
      client = MockSupabaseClient();
      repo = EntryRepository(MockEntryCrudService(), EntryQueryService(client));
    });

    test('a 23:30 only-entry counts for its own day', () async {
      _serveTrackedAt(client, [
        '2026-11-20T12:00',
        '2026-11-21T12:00',
        '2026-11-22T12:00',
        '2026-11-23T23:30',
      ]);

      final days = await repo.fetchActivityDays(
        userId: testUserId,
        since: DateTime(2026, 11, 1),
      );
      expect(days, {
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 21),
        DateTime(2026, 11, 22),
        DateTime(2026, 11, 23),
      });

      // That night the flame is lit…
      final tonight = evaluateStreak(
        activityDays: days,
        state: const BuddyState(savers: 1),
        today: DateTime(2026, 11, 23),
        windowStart: DateTime(2026, 11, 1),
      );
      expect(tonight.todayCounted, isTrue);
      expect(tonight.streak, 4);

      // …and the next morning nothing is missing: no saver, no break.
      final tomorrow = evaluateStreak(
        activityDays: days,
        state: const BuddyState(savers: 1),
        today: DateTime(2026, 11, 24),
        windowStart: DateTime(2026, 11, 1),
      );
      expect(tomorrow.streak, 4);
      expect(tomorrow.consumedDays, isEmpty);
      expect(tomorrow.streakBroken, isFalse);
    });

    test('a summer 22:15 entry stays on its day', () async {
      _serveTrackedAt(client, ['2026-07-14T22:15']);

      final days = await repo.fetchActivityDays(
        userId: testUserId,
        since: DateTime(2026, 7, 1),
      );

      expect(days, {DateTime(2026, 7, 14)});
    });

    test('the window bounds are sent as the wall clock', () async {
      final filters = _serveTrackedAt(client, const []);

      await repo.fetchActivityDays(
        userId: testUserId,
        since: DateTime(2026, 11, 1),
        until: DateTime(2026, 11, 24),
      );

      for (final f in filters.values) {
        verify(() => f.gte('tracked_at', '2026-11-01T00:00:00.000Z')).called(1);
        verify(() => f.lt('tracked_at', '2026-11-24T00:00:00.000Z')).called(1);
      }
    });
  });
}
