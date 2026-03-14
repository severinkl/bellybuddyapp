import '../models/drink.dart';
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
    final startOfDay = DateTime(now.year, now.month, now.day);
    final data = await SupabaseService.client
        .from('drink_entries')
        .select('amount_ml')
        .eq('user_id', userId)
        .gte('tracked_at', startOfDay.toIso8601String())
        .lt('tracked_at',
            startOfDay.add(const Duration(days: 1)).toIso8601String());
    return data.fold<int>(0, (sum, e) => sum + (e['amount_ml'] as int));
  }
}
