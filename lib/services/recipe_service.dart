import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/adapted_recipe.dart';
import '../models/intolerance_rules.dart';
import '../models/recipe.dart';
import '../providers/core_providers.dart';
import '../utils/function_exception_utils.dart';
import '../utils/logger.dart';

class RecipeService {
  final SupabaseClient _client;

  RecipeService(this._client);

  static const _log = AppLogger('RecipeService');

  /// Postgres' unique violation: the row is already there.
  static const _pgUniqueViolation = '23505';

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
          // The client's order() is descending unless told otherwise.
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

  /// Saves [recipeId] for [userId]. Already saved (another device, or a
  /// write that landed before its answer got lost) counts as done.
  Future<void> addFavorite(String userId, String recipeId) async {
    try {
      await _client.from('user_favorite_recipes').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } on PostgrestException catch (e, st) {
      if (e.code == _pgUniqueViolation) {
        _log.debug('addFavorite: already saved');
        return;
      }
      _log.error('addFavorite failed', e, st);
      rethrow;
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
  /// row is missing or isn't a JSON object.
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

  /// Core's `adapt-recipe` for [recipeId]. The body is the id alone: the
  /// server reads the intolerances and the diet itself, and no diary data is
  /// sent. Every failure is an [AdaptRecipeException].
  Future<AdaptedRecipe> adapt(String recipeId) async {
    final Object? data;
    try {
      final response = await _client.functions.invoke(
        'adapt-recipe',
        body: {'recipe_id': recipeId},
      );
      data = response.data;
    } on FunctionException catch (e, st) {
      final failure = _failureOf(e);
      // A 400 is the app's request at fault: logged like a failure.
      if (failure == AdaptFailure.failed || e.status == 400) {
        _log.error('adapt failed (${e.status})', e, st);
      } else {
        _log.warn('adapt: ${e.status} ${e.errorCode}');
      }
      throw AdaptRecipeException(failure);
    } catch (e, st) {
      _log.error('adapt failed', e, st);
      throw const AdaptRecipeException(AdaptFailure.failed);
    }
    try {
      if (data is! Map<String, dynamic>) {
        throw FormatException('not a JSON object: ${data.runtimeType}');
      }
      return AdaptedRecipe.fromJson(data);
    } catch (e, st) {
      _log.error('adapt: unreadable answer', e, st);
      throw const AdaptRecipeException(AdaptFailure.failed);
    }
  }

  /// The failure for an `adapt-recipe` error, keyed off its `code` (the
  /// server's message is never shown).
  static AdaptFailure _failureOf(FunctionException e) =>
      switch ((e.status, e.errorCode)) {
        (409, 'nothing_to_adapt') => AdaptFailure.nothingToAdapt,
        (409, 'cannot_judge') => AdaptFailure.cannotJudge,
        (404, 'recipe_not_found') || (400, _) => AdaptFailure.notFound,
        (429, _) => AdaptFailure.later,
        (402, 'plus_required') => AdaptFailure.plusRequired,
        _ => AdaptFailure.failed,
      };
}

final recipeServiceProvider = Provider<RecipeService>(
  (ref) => RecipeService(ref.watch(supabaseClientProvider)),
);
