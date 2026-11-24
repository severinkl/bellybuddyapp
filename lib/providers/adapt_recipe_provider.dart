import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/adapted_recipe.dart';
import '../repositories/recipe_repository.dart';
import '../utils/retry_helper.dart';

/// „Für mich anpassen" for the collection recipe [recipeId]: null while
/// idle, then the adapted recipe or an [AdaptRecipeException].
///
/// Nothing is sent until [start]: building the provider (opening the screen)
/// costs nothing. No client cache: the result lives while the screen does.
class AdaptRecipeNotifier extends AsyncNotifier<AdaptedRecipe?> {
  AdaptRecipeNotifier(this.recipeId);

  final String recipeId;

  @override
  AdaptedRecipe? build() => null;

  /// Asks for the adaptation; nothing while one is on its way or there is
  /// already a result.
  Future<void> start() async {
    if (state.isLoading || state.value != null) return;
    await _adapt();
  }

  /// Asks again, a result or not; nothing while one is on its way.
  Future<void> retry() async {
    if (state.isLoading) return;
    await _adapt();
  }

  Future<void> _adapt() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(recipeRepositoryProvider).adapt(recipeId),
    );
    // Closed while waiting: the answer has nowhere to go.
    if (ref.mounted) state = result;
  }
}

final adaptRecipeProvider = AsyncNotifierProvider.autoDispose
    .family<AdaptRecipeNotifier, AdaptedRecipe?, String>(
      (id) => AdaptRecipeNotifier(id),
      retry: noRetry,
    );
