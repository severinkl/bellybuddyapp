import '../utils/logger.dart';
import 'supabase_service.dart';

/// Table name for each entry type
const entryTableFor = {
  'meal': 'meal_entries',
  'toilet': 'toilet_entries',
  'gutFeeling': 'gut_feeling_entries',
  'drink': 'drink_entries',
};

/// Low-level CRUD operations for diary entry tables.
class EntryCrudService {
  static const _log = AppLogger('EntryCrudService');

  static Future<void> insert(String table, Map<String, dynamic> data) async {
    data['user_id'] = SupabaseService.userId;
    data.remove('id');
    data.remove('created_at');
    try {
      await SupabaseService.client.from(table).insert(data);
    } catch (e, st) {
      _log.error('insert into $table failed', e, st);
      rethrow;
    }
  }

  static Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at');
    try {
      await SupabaseService.client.from(table).update(data).eq('id', id);
    } catch (e, st) {
      _log.error('update $table/$id failed', e, st);
      rethrow;
    }
  }

  static Future<void> delete(String table, String id) async {
    try {
      await SupabaseService.client.from(table).delete().eq('id', id);
    } catch (e, st) {
      _log.error('delete $table/$id failed', e, st);
      rethrow;
    }
  }

  static Future<void> deleteByType(String type, String id) async {
    final table = switch (type) {
      'meal' => entryTableFor['meal']!,
      'toilet' => entryTableFor['toilet']!,
      'gutFeeling' => entryTableFor['gutFeeling']!,
      'drink' => entryTableFor['drink']!,
      _ => throw ArgumentError('Unknown entry type: $type'),
    };
    await delete(table, id);
  }
}
