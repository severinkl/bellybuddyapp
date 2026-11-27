import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drink.dart';
import '../models/drink_entry.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import '../utils/wall_clock.dart';

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

  /// The ml the user drank on [day]'s local day.
  Future<int> fetchDayTotal(String userId, DateTime day) async {
    try {
      final data = await _client
          .from('drink_entries')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('tracked_at', wallClockToWire(startOfDay(day)))
          .lt('tracked_at', wallClockToWire(endOfDay(day)));
      return data.fold<int>(0, (sum, e) => sum + (e['amount_ml'] as int));
    } catch (e, st) {
      _log.error('fetchDayTotal failed', e, st);
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

  /// The user's newest entry (latest `tracked_at`, ties by latest
  /// `created_at`) with its drink name, or null without entries.
  Future<DrinkEntry?> fetchLastEntry(String userId) async {
    try {
      final data = await _client
          .from('drink_entries')
          .select('*, drinks(name)')
          .eq('user_id', userId)
          .order('tracked_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data == null ? null : DrinkEntry.fromDbRow(data);
    } catch (e, st) {
      _log.error('fetchLastEntry failed', e, st);
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
