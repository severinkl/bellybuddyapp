import 'supabase_service.dart';

class IngredientService {
  static Future<List<String>> search(String query, {int limit = 10}) async {
    final data = await SupabaseService.client
        .from('ingredients')
        .select('name')
        .ilike('name', '%$query%')
        .limit(limit);
    return data.map((e) => e['name'] as String).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchSuggestions(
      String userId) async {
    return await SupabaseService.client
        .from('ingredient_suggestions')
        .select('*, ingredients(name)')
        .eq('user_id', userId)
        .isFilter('dismissed_at', null)
        .order('created_at', ascending: false);
  }

  static Future<void> dismissSuggestion(String id) async {
    await SupabaseService.client
        .from('ingredient_suggestions')
        .update({'dismissed_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  static Future<void> markSuggestionSeen(String id) async {
    await SupabaseService.client
        .from('ingredient_suggestions')
        .update({'seen_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
