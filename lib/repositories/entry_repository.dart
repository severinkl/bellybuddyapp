import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/entry_crud_service.dart';
import '../services/entry_query_service.dart';

/// Table name for each entry type
const entryTableFor = {
  'meal': 'meal_entries',
  'toilet': 'toilet_entries',
  'gutFeeling': 'gut_feeling_entries',
  'drink': 'drink_entries',
};

class EntryRepository {
  final EntryCrudService _crudService;
  final EntryQueryService _queryService;
  EntryRepository(this._crudService, this._queryService);

  Future<EntryQueryResult> fetchForDate({
    required String userId,
    required DateTime date,
    bool ordered = false,
  }) => _queryService.fetchEntriesForDateRange(
    userId: userId,
    date: date,
    ordered: ordered,
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
