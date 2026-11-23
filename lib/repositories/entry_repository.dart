import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
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

  /// Local calendar days (date-only) with at least one entry since [since]
  /// (and, with [until], before [until]).
  Future<Set<DateTime>> fetchActivityDays({
    required String userId,
    required DateTime since,
    DateTime? until,
  }) async {
    final instants = await _queryService.fetchTrackedAtSince(
      userId: userId,
      since: since,
      until: until,
    );
    return {for (final i in instants) startOfDay(i.toLocal())};
  }

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
