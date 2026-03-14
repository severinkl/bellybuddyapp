import 'supabase_service.dart';

class IngredientSuggestion {
  final String id;
  final String name;
  final bool isOwn;

  const IngredientSuggestion({
    required this.id,
    required this.name,
    required this.isOwn,
  });
}

class IngredientService {
  static Future<List<IngredientSuggestion>> search(String query,
      {int limit = 10}) async {
    final userId = SupabaseService.userId;
    final data = await SupabaseService.client
        .from('ingredients')
        .select('id, name, added_by_user_id')
        .ilike('name', '%$query%')
        .limit(limit);
    return data
        .map((e) => IngredientSuggestion(
              id: e['id'] as String,
              name: e['name'] as String,
              isOwn: e['added_by_user_id'] == userId,
            ))
        .toList();
  }

  static Future<void> insertIfNew(String name) async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    final existing = await SupabaseService.client
        .from('ingredients')
        .select('id')
        .ilike('name', name)
        .limit(1);
    if (existing.isNotEmpty) return;
    await SupabaseService.client.from('ingredients').insert({
      'name': name,
      'added_via': 'user',
      'added_by_user_id': userId,
    });
  }

  static Future<void> deleteUserIngredient(String id) async {
    await SupabaseService.client.from('ingredients').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> fetchSuggestions(
      String userId) async {
    return await SupabaseService.client
        .from('ingredient_suggestions')
        .select(
            'id, detected_ingredient_id, helptext, meal_id, seen_at, dismissed_at, '
            'ingredients!ingredient_suggestions_detected_ingredient_id_fkey(id, name, image_url)')
        .eq('user_id', userId)
        .isFilter('dismissed_at', null);
  }

  static Future<List<Map<String, dynamic>>> fetchReplacements(
      List<String> suggestionIds) async {
    if (suggestionIds.isEmpty) return [];
    return await SupabaseService.client
        .from('ingredient_suggestion_replacements')
        .select('suggestion_id, ingredients(id, name, image_url)')
        .inFilter('suggestion_id', suggestionIds);
  }

  static Future<List<Map<String, dynamic>>> fetchMealDetails(
      List<String> mealIds) async {
    if (mealIds.isEmpty) return [];
    return await SupabaseService.client
        .from('meal_entries')
        .select('id, title, tracked_at, image_url')
        .inFilter('id', mealIds);
  }

  static Future<void> markAllSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    await SupabaseService.client
        .from('ingredient_suggestions')
        .update({'seen_at': DateTime.now().toIso8601String()})
        .inFilter('id', ids);
  }

  static Future<void> dismissSuggestions(List<String> ids) async {
    if (ids.isEmpty) return;
    await SupabaseService.client
        .from('ingredient_suggestions')
        .update({'dismissed_at': DateTime.now().toIso8601String()})
        .inFilter('id', ids);
  }

  static Future<int> fetchNewCount(String userId) async {
    final data = await SupabaseService.client
        .from('ingredient_suggestions')
        .select('id')
        .eq('user_id', userId)
        .isFilter('seen_at', null)
        .isFilter('dismissed_at', null);
    return data.length;
  }
}
