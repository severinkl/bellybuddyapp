import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/adapted_recipe.dart';
import '../models/user_recipe.dart';
import '../providers/core_providers.dart';
import '../repositories/user_recipe_repository.dart';
import '../services/user_recipe_service.dart';
import '../utils/distinct_by_name.dart';
import '../utils/logger.dart';

final userRecipeServiceProvider = Provider<UserRecipeService>((ref) {
  return UserRecipeService(ref.watch(supabaseClientProvider));
});

final userRecipeRepositoryProvider = Provider<UserRecipeRepository>((ref) {
  return UserRecipeRepository(ref.watch(userRecipeServiceProvider));
});

/// The user's recipes, unfiltered. A screen's search is
/// `recipeSearchProvider`.
class UserRecipesNotifier extends Notifier<AsyncValue<List<UserRecipe>>> {
  static const _log = AppLogger('UserRecipesNotifier');

  @override
  AsyncValue<List<UserRecipe>> build() => const AsyncValue.loading();

  /// Fetches the user's recipes. When [force] is false (the default) and the
  /// provider already has data, the method short-circuits — screens that open
  /// and call fetch() as a post-frame initializer skip a redundant round-trip
  /// when the list is already cached. Mutations inside this notifier pass
  /// [force: true] so the list stays in sync after create/update/delete.
  Future<void> fetch({bool force = false}) async {
    if (state.hasValue && !force) return;
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
    List<String> instructions = const [],
    List<String?>? ingredientAmounts,
    String? adaptedFromRecipeId,
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
          instructions: instructions,
          ingredientAmounts: ingredientAmounts,
          adaptedFromRecipeId: adaptedFromRecipeId,
        );
    await fetch(force: true);
    return recipe;
  }

  Future<UserRecipe> update({
    required String id,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
    List<String>? instructions,
    List<String?>? ingredientAmounts,
  }) async {
    final recipe = await ref
        .read(userRecipeRepositoryProvider)
        .update(
          id: id,
          title: title,
          ingredients: ingredients,
          imageUrl: imageUrl,
          instructions: instructions,
          ingredientAmounts: ingredientAmounts,
        );
    await fetch(force: true);
    return recipe;
  }

  /// Saves [adapted] (clean since [AdaptedRecipe.fromJson]) as an own
  /// recipe: the names de-duplicated case-insensitively (the first and its
  /// amount kept), the amounts aligned (none when every one is null), the
  /// steps up to [AppConstants.recipeStepsMax], the original as its origin,
  /// no photo.
  ///
  /// When the title is taken, tries „<title> (angepasst)", then
  /// „(angepasst 2)" … „(angepasst 9)"; after that the
  /// [DuplicateRecipeTitleException] is rethrown.
  ///
  /// Steps or amounts longer than core allows throw a
  /// [RecipeTooLongException] before anything is sent: core would refuse
  /// them every time.
  Future<UserRecipe> createAdapted(AdaptedRecipe adapted) async {
    final kept = distinctByName(adapted.ingredients, (i) => i.name);
    final amounts = [for (final i in kept) i.amount];
    final steps = [
      for (final step in adapted.steps.take(AppConstants.recipeStepsMax))
        step.text,
    ];
    if (_chars(steps) > AppConstants.recipeStepsMaxChars ||
        _chars(amounts) > AppConstants.recipeAmountsMaxChars) {
      throw const RecipeTooLongException();
    }
    final title = adapted.title;
    for (var attempt = 0; ; attempt++) {
      try {
        return await create(
          title: switch (attempt) {
            0 => title,
            1 => '$title (angepasst)',
            _ => '$title (angepasst $attempt)',
          },
          ingredients: [for (final i in kept) i.name],
          instructions: steps,
          ingredientAmounts: amounts.every((a) => a == null) ? null : amounts,
          adaptedFromRecipeId: adapted.recipeId,
        );
      } on DuplicateRecipeTitleException {
        if (attempt >= _adaptedTitleAttempts - 1) rethrow;
      }
    }
  }

  /// The plain title, then „(angepasst)" and „(angepasst 2)" … „(angepasst 9)".
  static const _adaptedTitleAttempts = 10;

  /// The characters of [texts] together, as the editor counts them.
  static int _chars(Iterable<String?> texts) =>
      texts.fold(0, (sum, t) => sum + (t?.length ?? 0));

  Future<void> delete(String id) async {
    await ref.read(userRecipeRepositoryProvider).delete(id);
    await fetch(force: true);
  }
}

final userRecipesProvider =
    NotifierProvider<UserRecipesNotifier, AsyncValue<List<UserRecipe>>>(
      UserRecipesNotifier.new,
    );
