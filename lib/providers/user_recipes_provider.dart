import 'dart:async';

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
  static const _debounceDuration = Duration(milliseconds: 300);

  String? _query;
  Timer? _debounce;

  @override
  AsyncValue<List<UserRecipe>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return const AsyncValue.loading();
  }

  /// Sets the active search query. Empty / whitespace-only values clear it
  /// and the next fetch falls back to the unfiltered list. Calls debounce
  /// for [_debounceDuration]; identical queries are a no-op.
  void setQuery(String? q) {
    final next = (q == null || q.trim().isEmpty) ? null : q.trim();
    if (_query == next) return;
    _query = next;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      fetch(force: true);
    });
  }

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
      final repo = ref.read(userRecipeRepositoryProvider);
      final query = _query;
      final recipes = (query == null)
          ? await repo.fetchForUser(userId)
          : await repo.searchForUser(userId, query);
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
    await fetch(force: true);
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
    await fetch(force: true);
    return recipe;
  }

  Future<void> delete(String id) async {
    await ref.read(userRecipeRepositoryProvider).delete(id);
    await fetch(force: true);
  }
}

final userRecipesProvider =
    NotifierProvider<UserRecipesNotifier, AsyncValue<List<UserRecipe>>>(
      UserRecipesNotifier.new,
    );
