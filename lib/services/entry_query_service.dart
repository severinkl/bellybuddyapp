import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

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

  static Future<EntryQueryResult> fetchEntriesForDateRange({
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
        return SupabaseService.client
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
}
