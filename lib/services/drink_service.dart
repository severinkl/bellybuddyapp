import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drink.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

class DrinkService {
  final SupabaseClient _client;

  DrinkService(this._client);

  static const _log = AppLogger('DrinkService');

  Future<List<Drink>> fetchAll() async {
    try {
      final data = await _client.from('drinks').select().order('name');
      return data.map((e) => Drink.fromDbRow(e)).toList();
    } catch (e, st) {
      _log.error('fetchAll failed', e, st);
      rethrow;
    }
  }

  Future<int> fetchTodayTotal(String userId) async {
    try {
      final now = DateTime.now();
      final data = await _client
          .from('drink_entries')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('tracked_at', startOfDay(now).toIso8601String())
          .lt('tracked_at', endOfDay(now).toIso8601String());
      return data.fold<int>(0, (sum, e) => sum + (e['amount_ml'] as int));
    } catch (e, st) {
      _log.error('fetchTodayTotal failed', e, st);
      rethrow;
    }
  }

  /// Fetches deduplicated recent drink IDs ordered by most recent first.
  Future<List<String>> fetchRecentDrinkIds(String userId) async {
    try {
      final data = await _client
          .from('drink_entries')
          .select('drink_id')
          .eq('user_id', userId)
          .order('tracked_at', ascending: false)
          .limit(20);
      final seen = <String>{};
      return data
          .map((e) => e['drink_id'] as String)
          .where((id) => seen.add(id))
          .take(10)
          .toList();
    } catch (e, st) {
      _log.error('fetchRecentDrinkIds failed', e, st);
      rethrow;
    }
  }

  /// Inserts a new user-owned drink and returns the created record.
  Future<Drink> insertDrink(String name, {required String userId}) async {
    try {
      final data = await _client
          .from('drinks')
          .insert({
            'name': name,
            'added_via': 'user',
            'added_by_user_id': userId,
          })
          .select()
          .single();
      return Drink.fromDbRow(data);
    } catch (e, st) {
      _log.error('insertDrink failed', e, st);
      rethrow;
    }
  }

  /// Deletes a user-owned drink and all its associated entries.
  Future<void> deleteDrink(String drinkId) async {
    try {
      await _client.from('drink_entries').delete().eq('drink_id', drinkId);
      await _client.from('drinks').delete().eq('id', drinkId);
    } catch (e, st) {
      _log.error('deleteDrink failed', e, st);
      rethrow;
    }
  }
}

final drinkServiceProvider = Provider<DrinkService>(
  (ref) => DrinkService(ref.watch(supabaseClientProvider)),
);
