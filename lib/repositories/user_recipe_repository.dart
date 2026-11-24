import '../models/user_recipe.dart';
import '../services/user_recipe_service.dart';

class UserRecipeRepository {
  UserRecipeRepository(this._service);

  final UserRecipeService _service;

  Future<List<UserRecipe>> fetchForUser(String userId) =>
      _service.fetchForUser(userId);

  Future<List<UserRecipe>> searchForUser(String userId, String query) =>
      _service.searchForUser(userId, query);

  Future<UserRecipe> create({
    required String userId,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
    List<String> instructions = const [],
    List<String?>? ingredientAmounts,
    String? adaptedFromRecipeId,
  }) => _service.create(
    userId: userId,
    title: title,
    ingredients: ingredients,
    imageUrl: imageUrl,
    instructions: instructions,
    ingredientAmounts: ingredientAmounts,
    adaptedFromRecipeId: adaptedFromRecipeId,
  );

  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
    List<String>? instructions,
    List<String?>? ingredientAmounts,
  }) => _service.update(
    id: id,
    title: title,
    ingredients: ingredients,
    imageUrl: imageUrl,
    instructions: instructions,
    ingredientAmounts: ingredientAmounts,
  );

  Future<void> delete(String id) => _service.delete(id);
}
