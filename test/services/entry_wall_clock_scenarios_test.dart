import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/buddy/streak_engine.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';

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

/// A `range` that answers with one settled page.
class _Page extends MockPostgrestTransformBuilder {
  _Page(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) => _Settled(Future.value(from == 0 ? _rows : <Map<String, dynamic>>[]));
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

/// Serves [wallClocks] (as wire values) from [table] and nothing from the
/// other entry tables; returns each table's filter builder.
Map<String, SettlableFilterBuilder> _serveTrackedAt(
  MockSupabaseClient client,
  List<String> wallClocks, {
  String table = 'meal_entries',
}) {
  final filters = <String, SettlableFilterBuilder>{};
  for (final t in entryTableFor.values) {
    final qb = MockSupabaseQueryBuilder();
    final f = SettlableFilterBuilder(Future.value(<Map<String, dynamic>>[]));
    final rows = t == table
        ? [
            for (final w in wallClocks) {'tracked_at': _wire(w)},
          ]
        : <Map<String, dynamic>>[];
    when(() => client.from(t)).thenAnswer((_) => qb);
    when(() => qb.select(any())).thenAnswer((_) => f);
    when(() => f.eq(any(), any())).thenAnswer((_) => f);
    when(() => f.gte(any(), any())).thenAnswer((_) => f);
    when(() => f.lt(any(), any())).thenAnswer((_) => f);
    when(
      () => f.order(any(), ascending: any(named: 'ascending')),
    ).thenAnswer((_) => _Page(rows));
    filters[t] = f;
  }
  return filters;
}

void main() {
  group('Pflege-Ring', () {
    test('a 23:30 entry of every kind counts for its own day', () {
      final care = DailyCare.fromEntries(
        EntriesState(
          meals: [_meal('2026-11-23T23:30')],
          drinks: [_drink('2026-11-23T23:30')],
          gutFeelings: [_gutFeeling('2026-11-23T23:30')],
          toiletEntries: [_toilet('2026-11-23T23:30')],
        ),
        DateTime(2026, 11, 23, 23, 45),
      );

      expect(care.meals, 1);
      expect(care.drinks, 1);
      expect(care.glasses, 1);
      expect(care.gutFeelings, 1);
      expect(care.toilets, 1);
      expect(care.lastMealAt, DateTime(2026, 11, 23, 23, 30));
      expect(care.lastLogAt, DateTime(2026, 11, 23, 23, 30));
    });

    test("yesterday's 23:30 entry is not today's", () {
      final care = DailyCare.fromEntries(
        EntriesState(meals: [_meal('2026-11-22T23:30')]),
        DateTime(2026, 11, 23, 0, 15),
      );

      expect(care.meals, 0);
    });
  });

  group("the day's Bauchgefühl", () {
    test('a bad 23:30 check-in is the latest of the day', () {
      final care = DailyCare.fromEntries(
        EntriesState(
          gutFeelings: [
            _gutFeeling('2026-11-23T12:00'),
            _gutFeeling('2026-11-23T23:30', bloating: 5),
          ],
        ),
        DateTime(2026, 11, 23, 23, 45),
      );

      expect(care.gutFeelings, 2);
      expect(care.lastGutFeelingLevel, GutFeelingRatingLevel.schlecht);
    });
  });

  group('thirst pause (Buddy hero)', () {
    test('a drink read back after a restart is in the past, not ahead', () {
      final now = DateTime(2026, 11, 23, 4, 58);
      final care = DailyCare.fromEntries(
        EntriesState(drinks: [_drink('2026-11-23T04:38')]),
        now,
      );

      expect(care.lastDrinkAt, DateTime(2026, 11, 23, 4, 38));
      expect(care.lastDrinkAt!.isAfter(now), isFalse);
      expect(now.difference(care.lastDrinkAt!), const Duration(minutes: 20));
    });
  });

  group('meal prompt', () {
    test('a 09:45 breakfast is breakfast: Mittagessen is asked at 11:00', () {
      final now = DateTime(2026, 11, 23, 11);
      final care = DailyCare.fromEntries(
        EntriesState(meals: [_meal('2026-11-23T09:45')]),
        now,
      );

      expect(care.lastMealAt, DateTime(2026, 11, 23, 9, 45));
      expect(nextCareAction(care, now), CareAction.lunch);
    });

    test('a 16:15 snack is no dinner: Abendessen is asked at 17:30', () {
      final now = DateTime(2026, 11, 23, 17, 30);
      final care = DailyCare.fromEntries(
        EntriesState(meals: [_meal('2026-11-23T16:15')]),
        now,
      );

      expect(nextCareAction(care, now), CareAction.dinner);
    });

    test('in summer (CEST) a 15:15 snack is no dinner either', () {
      final now = DateTime(2026, 7, 14, 17, 30);
      final care = DailyCare.fromEntries(
        EntriesState(meals: [_meal('2026-07-14T15:15')]),
        now,
      );

      expect(nextCareAction(care, now), CareAction.dinner);
    });
  });

  group('Buddy mood', () {
    test('happy for 5 hours after the last entry, not longer', () {
      final entries = EntriesState(drinks: [_drink('2026-11-23T10:00')]);
      DailyCare at(DateTime now) => DailyCare.fromEntries(entries, now);

      final happy = DateTime(2026, 11, 23, 14, 30);
      final later = DateTime(2026, 11, 23, 15, 30);
      expect(deriveBuddyMood(at(happy), happy), BuddyMood.happy);
      expect(deriveBuddyMood(at(later), later), BuddyMood.hungry);
    });
  });

  group('Muster progress', () {
    late MockSupabaseClient client;
    late EntryRepository repo;

    setUp(() {
      client = MockSupabaseClient();
      repo = EntryRepository(MockEntryCrudService(), EntryQueryService(client));
    });

    test('late check-ins count, each on its own day', () async {
      final filters = _serveTrackedAt(client, [
        '2026-11-21T23:30',
        '2026-11-22T23:30',
        '2026-11-23T23:30',
      ], table: 'gut_feeling_entries');

      final progress = await repo.fetchInsightProgress(
        userId: testUserId,
        now: DateTime(2026, 11, 23, 23, 45),
      );

      expect(
        progress,
        const InsightProgress(activeDays: 3, gutFeelingEntries: 3),
      );
      // The window starts at local midnight 29 days back, as the wall clock.
      verify(
        () => filters['gut_feeling_entries']!.gte(
          'tracked_at',
          '2026-10-25T00:00:00.000Z',
        ),
      ).called(2);
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
