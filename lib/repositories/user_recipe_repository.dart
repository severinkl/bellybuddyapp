import '../models/user_recipe.dart';
import '../services/user_recipe_service.dart';

class UserRecipeRepository {
  UserRecipeRepository(this._service);

  final UserRecipeService _service;

  Future<List<UserRecipe>> fetchForUser(String userId) =>
      _service.fetchForUser(userId);

  Future<UserRecipe> create({
    required String userId,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) => _service.create(
    userId: userId,
    title: title,
    ingredients: ingredients,
    imageUrl: imageUrl,
  );

  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) => _service.update(
    id: id,
    title: title,
    ingredients: ingredients,
    imageUrl: imageUrl,
  );

  Future<void> delete(String id) => _service.delete(id);
}
