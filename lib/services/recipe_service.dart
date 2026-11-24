import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/intolerance_rules.dart';
import '../models/recipe.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

class RecipeService {
  final SupabaseClient _client;

  RecipeService(this._client);

  static const _log = AppLogger('RecipeService');

  /// Core's collection select: the recipes, their lines and each line's
  /// catalog FODMAP flags (the API contract of core PR #11). `ingredients` is
  /// the text column the older recipes show instead of lines.
  static const collectionSelect =
      'id,title,description,cook_time,servings,image_url,meal_types,diet_tags,source_name,source_url,'
      'instructions,ingredients,created_at,'
      'recipe_ingredients(position,amount_text,name,allergens,low_at_amount,'
      'ingredient:ingredients(id,name,fodmap_fructans,fodmap_gos,fodmap_lactose,fodmap_fructose,fodmap_sorbitol,fodmap_mannitol))';

  /// The visible collection, newest first, each recipe's lines in order.
  Future<List<Recipe>> fetchCollection() async {
    try {
      final data = await _client
          .from('recipes')
          .select(collectionSelect)
          // RLS hides hidden recipes from users, but admins still read them.
          .isFilter('hidden', false)
          .order('created_at', ascending: false)
          // PostgREST orders descending unless told otherwise.
          .order(
            'position',
            ascending: true,
            referencedTable: 'recipe_ingredients',
          );
      return data.map(Recipe.fromJson).toList();
    } catch (e, st) {
      _log.error('fetchCollection failed', e, st);
      rethrow;
    }
  }

  /// The user's favourites, newest first.
  Future<List<FavoriteRecipe>> fetchFavorites(String userId) async {
    try {
      final data = await _client
          .from('user_favorite_recipes')
          .select('recipe_id,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return [
        for (final row in data)
          FavoriteRecipe(
            row['recipe_id'] as String,
            DateTime.parse(row['created_at'] as String),
          ),
      ];
    } catch (e, st) {
      _log.error('fetchFavorites failed', e, st);
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

  /// Core's intolerance table (`app_config.intolerance_rules`). Null when the
  /// row is missing (a backend without core #11) or isn't a JSON object.
  Future<IntoleranceRules?> fetchIntoleranceRules() async {
    try {
      final row = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'intolerance_rules')
          .maybeSingle();
      final value = row?['value'];
      final rules = value is String ? IntoleranceRules.parse(value) : null;
      if (rules == null) {
        _log.warn(
          row == null
              ? 'intolerance_rules missing'
              : 'intolerance_rules is not a JSON object',
        );
      }
      return rules;
    } catch (e, st) {
      _log.error('fetchIntoleranceRules failed', e, st);
      rethrow;
    }
  }
}

final recipeServiceProvider = Provider<RecipeService>(
  (ref) => RecipeService(ref.watch(supabaseClientProvider)),
);
