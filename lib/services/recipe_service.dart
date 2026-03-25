import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class RecipeService {
  final SupabaseClient _client;

  RecipeService(this._client);

  static const _log = AppLogger('RecipeService');

  Future<List<Recipe>> fetchAll() async {
    try {
      final data = await _client.from('recipes').select().order('title');
      return data.map((e) => Recipe.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('fetchAll failed', e, st);
      rethrow;
    }
  }

  Future<Set<String>> fetchFavoriteIds(String userId) async {
    try {
      final data = await _client
          .from('user_favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);
      return data.map((e) => e['recipe_id'] as String).toSet();
    } catch (e, st) {
      _log.error('fetchFavoriteIds failed', e, st);
      rethrow;
    }
  }

  Future<void> addFavorite(String userId, String recipeId) async {
    try {
      await _client.from('user_favorite_recipes').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } catch (e, st) {
      _log.error('addFavorite failed', e, st);
      rethrow;
    }
  }

  Future<void> removeFavorite(String userId, String recipeId) async {
    try {
      await _client
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

final recipeServiceProvider = Provider<RecipeService>(
  (ref) => RecipeService(ref.watch(supabaseClientProvider)),
);
