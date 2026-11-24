import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/intolerance_rules.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecipeRepository {
  final RecipeService _recipeService;
  static const _log = AppLogger('RecipeRepository');

  RecipeRepository(this._recipeService);

  Future<List<Recipe>> fetchCollection() => retryAsync(
    _recipeService.fetchCollection,
    log: _log,
    label: 'fetchCollection',
  );

  Future<List<FavoriteRecipe>> fetchFavorites(String userId) =>
      _recipeService.fetchFavorites(userId);

  Future<void> addFavorite(String userId, String recipeId) =>
      _recipeService.addFavorite(userId, recipeId);

  Future<void> removeFavorite(String userId, String recipeId) =>
      _recipeService.removeFavorite(userId, recipeId);

  Future<IntoleranceRules?> fetchIntoleranceRules() =>
      _recipeService.fetchIntoleranceRules();
}

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(recipeServiceProvider)),
);
