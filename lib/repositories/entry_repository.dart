import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insight_rules.dart';
import '../models/insight_source.dart';
import '../models/meal_entry.dart';
import '../models/progress.dart';
import '../models/progress_rules.dart';
import '../services/entry_crud_service.dart';
import '../services/entry_query_service.dart';
import '../utils/date_format_utils.dart';

export '../config/entry_tables.dart';

class EntryRepository {
  final EntryCrudService _crudService;
  final EntryQueryService _queryService;
  EntryRepository(this._crudService, this._queryService);

  Future<List<MealEntry>> fetchRecentMeals({
    required String userId,
    int? limit,
  }) => _queryService.fetchRecentMeals(userId: userId, limit: limit);

  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) => _queryService.fetchEntriesForDateRange(
    userId: userId,
    date: date,
    ordered: ordered,
  );

  Future<LatestEntries> fetchLatestBefore({
    required String userId,
    required DateTime before,
  }) => _queryService.fetchLatestBefore(userId: userId, before: before);

  /// Local calendar days (date-only) with at least one entry since [since]
  /// (and, with [until], before [until]).
  Future<Set<DateTime>> fetchActivityDays({
    required String userId,
    required DateTime since,
    DateTime? until,
  }) async {
    final times = await _queryService.fetchTrackedAtSince(
      userId: userId,
      since: since,
      until: until,
    );
    return {for (final t in times) startOfDay(t)};
  }

  /// The last [InsightRules.windowDays] local days as of [now], today
  /// included, with meals reaching [InsightRules.mealsBefore] further back
  /// (a meal the evening before still counts for the first day's entries).
  Future<InsightSource> fetchInsightSource({
    required String userId,
    required DateTime now,
  }) {
    final since = addDays(startOfDay(now), -(InsightRules.windowDays - 1));
    return _queryService.fetchInsightSource(
      userId: userId,
      since: since,
      mealsSince: since.subtract(InsightRules.mealsBefore),
    );
  }

  /// „Dein Verlauf"'s window as of [now]: since the Monday of [now]'s
  /// local week minus [ProgressRules.weeks] − 1 weeks.
  Future<ProgressSource> fetchProgressSource({
    required String userId,
    required DateTime now,
  }) => _queryService.fetchProgressSource(
    userId: userId,
    since: addDays(mondayOf(startOfDay(now)), -7 * (ProgressRules.weeks - 1)),
  );

  Future<void> insertEntry(
    String table,
    Map<String, dynamic> data, {
    required String userId,
  }) => _crudService.insert(table, data, userId: userId);

  Future<void> updateEntry(
    String table,
    String id,
    Map<String, dynamic> data,
  ) => _crudService.update(table, id, data);

  Future<void> deleteEntry(String table, String id) =>
      _crudService.delete(table, id);

  Future<void> deleteByType(String type, String id) =>
      _crudService.deleteByType(type, id);
}

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepository(
    ref.watch(entryCrudServiceProvider),
    ref.watch(entryQueryServiceProvider),
  ),
);
