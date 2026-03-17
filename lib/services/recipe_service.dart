import '../models/recipe.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

class RecipeService {
  static const _log = AppLogger('RecipeService');

  static Future<List<Recipe>> fetchAll() async {
    try {
      final data = await SupabaseService.client
          .from('recipes')
          .select()
          .order('title');
      return data.map((e) => Recipe.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchAll failed', e, st);
      rethrow;
    }
  }

  static Future<Set<String>> fetchFavoriteIds(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('user_favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);
      return data.map((e) => e['recipe_id'] as String).toSet();
    } catch (e, st) {
      _log.error('fetchFavoriteIds failed', e, st);
      rethrow;
    }
  }

  static Future<void> addFavorite(String userId, String recipeId) async {
    try {
      await SupabaseService.client.from('user_favorite_recipes').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } catch (e, st) {
      _log.error('addFavorite failed', e, st);
      rethrow;
    }
  }

  static Future<void> removeFavorite(String userId, String recipeId) async {
    try {
      await SupabaseService.client
          .from('user_favorite_recipes')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
    } catch (e, st) {
      _log.error('removeFavorite failed', e, st);
      rethrow;
    }
  }
}
