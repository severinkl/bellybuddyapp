import '../models/recipe.dart';
import 'supabase_service.dart';

class RecipeService {
  static Future<List<Recipe>> fetchAll() async {
    final data = await SupabaseService.client
        .from('recipes')
        .select()
        .order('title');
    return data.map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<Set<String>> fetchFavoriteIds(String userId) async {
    final data = await SupabaseService.client
        .from('user_favorite_recipes')
        .select('recipe_id')
        .eq('user_id', userId);
    return data.map((e) => e['recipe_id'] as String).toSet();
  }

  static Future<void> addFavorite(String userId, String recipeId) async {
    await SupabaseService.client
        .from('user_favorite_recipes')
        .insert({'user_id': userId, 'recipe_id': recipeId});
  }

  static Future<void> removeFavorite(String userId, String recipeId) async {
    await SupabaseService.client
        .from('user_favorite_recipes')
        .delete()
        .eq('user_id', userId)
        .eq('recipe_id', recipeId);
  }
}
