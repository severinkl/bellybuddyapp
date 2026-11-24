import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/entry_tables.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../models/insight_source.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import '../utils/wall_clock.dart';

class EntryQueryResult {
  final List<MealEntry> meals;
  final List<ToiletEntry> toiletEntries;
  final List<GutFeelingEntry> gutFeelings;
  final List<DrinkEntry> drinks;

  const EntryQueryResult({
    required this.meals,
    required this.toiletEntries,
    required this.gutFeelings,
    required this.drinks,
  });
}

/// When the user last logged a meal, a drink and a Bauchgefühl before some
/// moment; null for a kind never logged then.
class LatestEntries {
  const LatestEntries({this.meal, this.drink, this.gutFeeling});

  final DateTime? meal;
  final DateTime? drink;
  final DateTime? gutFeeling;

  @override
  bool operator ==(Object other) =>
      other is LatestEntries &&
      other.meal == meal &&
      other.drink == drink &&
      other.gutFeeling == gutFeeling;

  @override
  int get hashCode => Object.hash(meal, drink, gutFeeling);
}

class EntryQueryService {
  static const _log = AppLogger('EntryQueryService');

  /// Matches PostgREST's PGRST_DB_MAX_ROWS on the backend.
  static const trackedAtPageSize = 1000;

  final SupabaseClient _client;
  EntryQueryService(this._client);

  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) async {
    try {
      var query = _client
          .from('meal_entries')
          .select()
          .eq('user_id', userId)
          .order('tracked_at', ascending: false);
      final data = limit != null ? await query.limit(limit) : await query;
      return data.map((e) => MealEntry.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchRecentMeals failed', e, st);
      rethrow;
    }
  }

  Future<EntryQueryResult> fetchEntriesForDateRange({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) async {
    try {
      final start = wallClockToWire(startOfDay(date));
      final end = wallClockToWire(endOfDay(date));

      PostgrestFilterBuilder<PostgrestList> baseQuery(
        String table, [
        String columns = '*',
      ]) {
        return _client
            .from(table)
            .select(columns)
            .eq('user_id', userId)
            .gte('tracked_at', start)
            .lt('tracked_at', end);
      }

      final List<Future<List<dynamic>>> futures;
      if (ordered) {
        futures = [
          baseQuery('meal_entries').order('tracked_at', ascending: false),
          baseQuery('toilet_entries').order('tracked_at', ascending: false),
          baseQuery(
            'gut_feeling_entries',
          ).order('tracked_at', ascending: false),
          baseQuery(
            'drink_entries',
            '*, drinks(name)',
          ).order('tracked_at', ascending: false),
        ];
      } else {
        futures = [
          baseQuery('meal_entries'),
          baseQuery('toilet_entries'),
          baseQuery('gut_feeling_entries'),
          baseQuery('drink_entries', '*, drinks(name)'),
        ];
      }

      final results = await Future.wait(futures);

      return EntryQueryResult(
        meals: results[0].map((e) => MealEntry.fromJson(e)).toList(),
        toiletEntries: results[1].map((e) => ToiletEntry.fromJson(e)).toList(),
        gutFeelings: results[2]
            .map((e) => GutFeelingEntry.fromJson(e))
            .toList(),
        drinks: results[3].map((e) => DrinkEntry.fromDbRow(e)).toList(),
      );
    } catch (e, st) {
      _log.error('fetchEntriesForDateRange failed for $date', e, st);
      rethrow;
    }
  }

  /// The `tracked_at` of the latest meal, drink and Bauchgefühl before
  /// [before]. Its string is the one [fetchEntriesForDateRange] starts a
  /// day at, so a day and the latest entries before it meet without a gap.
  Future<LatestEntries> fetchLatestBefore({
    required String userId,
    required DateTime before,
  }) async {
    try {
      final beforeIso = before.toIso8601String();
      Future<DateTime?> latest(String table) async {
        final rows = await _client
            .from(table)
            .select('tracked_at')
            .eq('user_id', userId)
            .lt('tracked_at', beforeIso)
            .order('tracked_at', ascending: false)
            .limit(1);
        return rows.isEmpty
            ? null
            : DateTime.parse(rows.first['tracked_at'] as String);
      }

      final results = await Future.wait([
        latest('meal_entries'),
        latest('drink_entries'),
        latest('gut_feeling_entries'),
      ]);
      return LatestEntries(
        meal: results[0],
        drink: results[1],
        gutFeeling: results[2],
      );
    } catch (e, st) {
      _log.error('fetchLatestBefore failed before $before', e, st);
      rethrow;
    }
  }

  /// Fetches `tracked_at` of every entry in [tables] (default: all four
  /// entry tables) since [since] and, with [until], before [until], as local
  /// wall-clock times.
  Future<List<DateTime>> fetchTrackedAtSince({
    required String userId,
    required DateTime since,
    DateTime? until,
    Iterable<String>? tables,
  }) async {
    try {
      final sinceIso = wallClockToWire(since);
      final untilIso = until == null ? null : wallClockToWire(until);
      final results = await Future.wait(
        (tables ?? entryTableFor.values).map(
          (t) => _fetchPaged(
            t,
            'tracked_at',
            userId,
            sinceIso,
            untilIso: untilIso,
          ),
        ),
      );
      return [
        for (final rows in results)
          for (final row in rows)
            wallClockFromWire(row['tracked_at'] as String),
      ];
    } catch (e, st) {
      _log.error('fetchTrackedAtSince failed', e, st);
      rethrow;
    }
  }

  /// The insight window's data in one select per table: meals (with their
  /// ingredients) since [mealsSince], gut feelings, Klo and drink entries
  /// since [since]. Meals before [since] only serve as lookback and are not
  /// activity.
  Future<InsightSource> fetchInsightSource({
    required String userId,
    required DateTime since,
    required DateTime mealsSince,
  }) async {
    try {
      final sinceIso = wallClockToWire(since);
      final mealsSinceIso = wallClockToWire(mealsSince);
      final results = await Future.wait([
        _fetchPaged(
          'meal_entries',
          'tracked_at, ingredients',
          userId,
          mealsSinceIso,
        ),
        _fetchPaged('gut_feeling_entries', '*', userId, sinceIso),
        _fetchPaged('toilet_entries', 'tracked_at', userId, sinceIso),
        _fetchPaged('drink_entries', 'tracked_at', userId, sinceIso),
      ]);
      DateTime trackedAt(Map<String, dynamic> row) =>
          wallClockFromWire(row['tracked_at'] as String);
      final meals = [
        for (final row in results[0])
          InsightMeal(
            trackedAt: trackedAt(row),
            ingredients: [
              for (final i
                  in (row['ingredients'] as List<dynamic>?) ?? const [])
                i as String,
            ],
          ),
      ];
      final gutFeelings = [
        for (final row in results[1]) GutFeelingEntry.fromJson(row),
      ];
      return InsightSource(
        meals: meals,
        gutFeelings: gutFeelings,
        activityTimes: [
          for (final m in meals)
            if (!m.trackedAt.isBefore(since)) m.trackedAt,
          for (final g in results[1]) trackedAt(g),
          for (final rows in results.skip(2))
            for (final row in rows) trackedAt(row),
        ],
      );
    } catch (e, st) {
      _log.error('fetchInsightSource failed', e, st);
      rethrow;
    }
  }

  /// Every row of [table] for [userId] with `tracked_at` since [sinceIso]
  /// (and before [untilIso]), page by page. The pages follow a total order
  /// (`tracked_at`, then the unique `id`), so rows sharing a `tracked_at`
  /// across a page boundary are neither repeated nor skipped.
  Future<List<Map<String, dynamic>>> _fetchPaged(
    String table,
    String columns,
    String userId,
    String sinceIso, {
    String? untilIso,
  }) async {
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      var query = _client
          .from(table)
          .select(columns)
          .eq('user_id', userId)
          .gte('tracked_at', sinceIso);
      if (untilIso != null) query = query.lt('tracked_at', untilIso);
      final page = await query
          .order('tracked_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + trackedAtPageSize - 1);
      all.addAll(page.cast<Map<String, dynamic>>());
      if (page.length < trackedAtPageSize) return all;
      from += trackedAtPageSize;
    }
  }
}

final entryQueryServiceProvider = Provider<EntryQueryService>(
  (ref) => EntryQueryService(ref.watch(supabaseClientProvider)),
);
