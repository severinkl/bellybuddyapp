import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_recipe.dart';
import '../utils/logger.dart';
import 'core_providers.dart';
import 'user_recipes_provider.dart';

/// Where a recipe search shows. Each host has its own search
/// ([recipeSearchProvider]), so two open at once (Meine Rezepte below the
/// meal tracker's picker) never share a query.
enum RecipeSearchHost {
  /// Meine Rezepte (Entdecken → „Alle ›").
  myRecipes,

  /// The meal tracker's „Rezept auswählen" sheet.
  recipePicker,
}

/// The recipe search of one host ([RecipeSearchHost]): the user's recipes,
/// or with a query the server's matches.
///
/// Auto-disposed: the search ends with the host that watches it, and
/// [userRecipesProvider] (Entdecken's preview, the meal tracker, the
/// detail screen) is never filtered.
class RecipeSearchNotifier extends Notifier<AsyncValue<List<UserRecipe>>> {
  static const _log = AppLogger('RecipeSearch');
  static const debounceDuration = Duration(milliseconds: 300);

  String? _query;
  Timer? _debounce;

  /// True iff a non-empty search query is active. The UI uses this to tell
  /// "no recipes saved" from "the search found nothing".
  bool get hasActiveQuery => _query != null;

  /// The active search query, or null if no search is active.
  String? get activeQuery => _query;

  @override
  AsyncValue<List<UserRecipe>> build() {
    ref.onDispose(() => _debounce?.cancel());
    // Listened, not watched: a rebuild would recreate this notifier and
    // drop the query. The user's recipes changed (loaded, edited): show
    // them, or search them again.
    ref.listen(userRecipesProvider, (_, all) {
      if (_query == null) {
        state = all;
      } else if (all.hasValue) {
        unawaited(_search());
      }
    });
    return ref.read(userRecipesProvider);
  }

  /// Sets the active search query. Empty / whitespace-only values clear it
  /// and the list falls back to all recipes. Takes effect after
  /// [debounceDuration]; identical queries are a no-op.
  void setQuery(String? q) {
    final next = (q == null || q.trim().isEmpty) ? null : q.trim();
    if (_query == next) return;
    _query = next;
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () => unawaited(_search()));
  }

  /// Loads the list again: the search's matches, or all recipes.
  Future<void> retry() => _search();

  /// Without a query, reloads all recipes (the listener shows them); with
  /// one, asks the server for its matches. Keeps the shown list while
  /// loading.
  Future<void> _search() async {
    final query = _query;
    if (query == null) {
      await ref.read(userRecipesProvider.notifier).fetch(force: true);
      if (ref.mounted && _query == null) state = ref.read(userRecipesProvider);
      return;
    }
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      final results = userId == null
          ? const <UserRecipe>[]
          : await ref
                .read(userRecipeRepositoryProvider)
                .searchForUser(userId, query);
      // Closed meanwhile, or a newer query is on its way.
      if (!ref.mounted || _query != query) return;
      state = AsyncValue.data(results);
    } catch (e, st) {
      _log.error('search failed', e, st);
      if (!ref.mounted || _query != query) return;
      state = AsyncValue.error(e, st);
    }
  }
}

/// The recipe search of [RecipeSearchHost] `host`.
final recipeSearchProvider = NotifierProvider.autoDispose
    .family<
      RecipeSearchNotifier,
      AsyncValue<List<UserRecipe>>,
      RecipeSearchHost
    >((_) => RecipeSearchNotifier());
