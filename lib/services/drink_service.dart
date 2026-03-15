import '../models/drink.dart';
import '../utils/date_format_utils.dart';
import 'supabase_service.dart';

class DrinkService {
  static Future<List<Drink>> fetchAll() async {
    final data = await SupabaseService.client
        .from('drinks')
        .select()
        .order('name');
    return data.map((e) => Drink.fromDbRow(e)).toList();
  }

  static Future<int> fetchTodayTotal(String userId) async {
    final now = DateTime.now();
    final data = await SupabaseService.client
        .from('drink_entries')
        .select('amount_ml')
        .eq('user_id', userId)
        .gte('tracked_at', startOfDay(now).toIso8601String())
        .lt('tracked_at', endOfDay(now).toIso8601String());
    return data.fold<int>(0, (sum, e) => sum + (e['amount_ml'] as int));
  }

  /// Fetches deduplicated recent drink IDs ordered by most recent first.
  static Future<List<String>> fetchRecentDrinkIds(String userId) async {
    final data = await SupabaseService.client
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
  }

  /// Deletes a user-owned drink.
  static Future<void> deleteDrink(String drinkId) async {
    await SupabaseService.client.from('drinks').delete().eq('id', drinkId);
  }
}
