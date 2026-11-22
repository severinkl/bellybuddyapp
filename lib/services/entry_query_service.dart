import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/entry_tables.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

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
      final start = startOfDay(date).toIso8601String();
      final end = endOfDay(date).toIso8601String();

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

  /// Fetches `tracked_at` of every entry (all four tables) since [since].
  Future<List<DateTime>> fetchTrackedAtSince({
    required String userId,
    required DateTime since,
  }) async {
    try {
      final sinceIso = since.toUtc().toIso8601String();
      final results = await Future.wait(
        entryTableFor.values.map(
          (t) => _fetchTrackedAtTable(t, userId, sinceIso),
        ),
      );
      return [
        for (final rows in results)
          for (final row in rows) DateTime.parse(row['tracked_at'] as String),
      ];
    } catch (e, st) {
      _log.error('fetchTrackedAtSince failed', e, st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTrackedAtTable(
    String table,
    String userId,
    String sinceIso,
  ) async {
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client
          .from(table)
          .select('tracked_at')
          .eq('user_id', userId)
          .gte('tracked_at', sinceIso)
          .order('tracked_at', ascending: false)
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
