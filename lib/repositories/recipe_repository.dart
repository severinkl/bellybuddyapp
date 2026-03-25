import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecipeRepository {
  final RecipeService _recipeService;
  static const _log = AppLogger('RecipeRepository');

  RecipeRepository(this._recipeService);

  Future<List<Recipe>> fetchAll() =>
      retryAsync(() => _recipeService.fetchAll(), log: _log, label: 'fetchAll');

  Future<Set<String>> fetchFavoriteIds(String userId) =>
      _recipeService.fetchFavoriteIds(userId);

  Future<void> addFavorite(String userId, String recipeId) =>
      _recipeService.addFavorite(userId, recipeId);

  Future<void> removeFavorite(String userId, String recipeId) =>
      _recipeService.removeFavorite(userId, recipeId);
}

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(recipeServiceProvider)),
);
