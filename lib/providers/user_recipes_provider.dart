import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_recipe.dart';
import '../providers/core_providers.dart';
import '../repositories/user_recipe_repository.dart';
import '../services/user_recipe_service.dart';
import '../utils/logger.dart';

final userRecipeServiceProvider = Provider<UserRecipeService>((ref) {
  return UserRecipeService(ref.watch(supabaseClientProvider));
});

final userRecipeRepositoryProvider = Provider<UserRecipeRepository>((ref) {
  return UserRecipeRepository(ref.watch(userRecipeServiceProvider));
});

class UserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>> {
  static const _log = AppLogger('UserRecipesNotifier');

  @override
  AsyncValue<List<UserRecipe>> build() => const AsyncValue.loading();

  Future<void> fetch() async {
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final recipes = await ref
          .read(userRecipeRepositoryProvider)
          .fetchForUser(userId);
      state = AsyncValue.data(recipes);
    } catch (e, st) {
      _log.error('fetch failed', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserRecipe> create({
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      throw StateError('create called with no signed-in user');
    }
    final recipe = await ref
        .read(userRecipeRepositoryProvider)
        .create(
          userId: userId,
          title: title,
          ingredients: ingredients,
          imageUrl: imageUrl,
        );
    await fetch();
    return recipe;
  }

  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
  }) async {
    final recipe = await ref
        .read(userRecipeRepositoryProvider)
        .update(
          id: id,
          title: title,
          ingredients: ingredients,
          imageUrl: imageUrl,
        );
    await fetch();
    return recipe;
  }

  Future<void> delete(String id) async {
    await ref.read(userRecipeRepositoryProvider).delete(id);
    await fetch();
  }
}

final userRecipesProvider =
    NotifierProvider<UserRecipesNotifier, AsyncValue<List<UserRecipe>>>(
      UserRecipesNotifier.new,
    );
