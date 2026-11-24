import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intolerance_rules.dart';
import '../models/my_recipe_item.dart';
import '../models/recipe.dart';
import '../repositories/recipe_repository.dart';
import '../services/recipes/recipe_fit.dart';
import '../services/recipes/recipe_ranking.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import '../utils/settled_value.dart';
import 'auth_provider.dart';
import 'insights_provider.dart';
import 'profile_provider.dart';
import 'user_scoped_refresh.dart';
import 'user_recipes_provider.dart';

const _log = AppLogger('RecipeCollection');
const _favLog = AppLogger('RecipeFavorites');

/// The visible recipe collection; empty while signed out. A failed load
/// stays an error (no automatic retries) until [refresh]; a refresh keeps
/// what is shown.
class RecipeCollectionNotifier extends AsyncNotifier<List<Recipe>>
    with UserScopedRefresh<List<Recipe>> {
  @override
  Future<List<Recipe>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    return ref.read(recipeRepositoryProvider).fetchCollection();
  }

  /// Fetches again ([refreshWith]), and the intolerance table when it
  /// failed or was missing (a loaded one stays).
  Future<void> refresh() {
    final rules = ref.read(intoleranceRulesProvider);
    if (ref.read(currentUserIdProvider) != null &&
        (rules.hasError || (rules.hasValue && rules.value == null))) {
      ref.invalidate(intoleranceRulesProvider);
    }
    return refreshWith(
      (_) => ref.read(recipeRepositoryProvider).fetchCollection(),
      _log,
    );
  }
}

final recipeCollectionProvider =
    AsyncNotifierProvider<RecipeCollectionNotifier, List<Recipe>>(
      RecipeCollectionNotifier.new,
      retry: noRetry,
    );

/// Core's intolerance table; null when the backend has none. A failed load
/// leaves the recipes unchecked.
final intoleranceRulesProvider = FutureProvider<IntoleranceRules?>(
  (ref) => ref.read(recipeRepositoryProvider).fetchIntoleranceRules(),
  retry: noRetry,
);

/// The recipes the user saved („Merken"), newest first.
class RecipeFavoritesNotifier extends AsyncNotifier<List<FavoriteRecipe>>
    with UserScopedRefresh<List<FavoriteRecipe>> {
  @override
  Future<List<FavoriteRecipe>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(recipeRepositoryProvider).fetchFavorites(userId);
  }

  bool isSaved(String recipeId) => state.isSaved(recipeId);

  /// Saves [recipeId], or removes it when saved; shown at once. Returns
  /// false, with the change taken back, when the write fails, and false
  /// without a change while the favourites aren't loaded.
  Future<bool> toggle(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    final current = state.settledValue;
    if (userId == null || current == null) return false;
    final index = current.indexWhere((f) => f.recipeId == recipeId);
    final removed = index < 0 ? null : current[index];
    state = AsyncData([
      if (removed == null) FavoriteRecipe(recipeId, DateTime.now()),
      for (final f in current)
        if (f.recipeId != recipeId) f,
    ]);
    final repo = ref.read(recipeRepositoryProvider);
    try {
      if (removed == null) {
        await repo.addFavorite(userId, recipeId);
      } else {
        await repo.removeFavorite(userId, recipeId);
      }
      return true;
    } catch (e, st) {
      _favLog.error('toggle favourite failed', e, st);
      // Take back only this recipe's change; other toggles stay. Nothing
      // to take back once another user is signed in.
      if (ref.isCurrentUser(userId)) {
        final now = [
          for (final f in state.value ?? const <FavoriteRecipe>[])
            if (f.recipeId != recipeId) f,
        ];
        if (removed != null) now.insert(index.clamp(0, now.length), removed);
        state = AsyncData(now);
      }
      return false;
    }
  }

  /// Fetches again ([refreshWith]).
  Future<void> refresh() =>
      refreshWith(ref.read(recipeRepositoryProvider).fetchFavorites, _favLog);
}

/// Whether [recipeId] is among the settled favourites; for a `select`.
extension SavedFavorites on AsyncValue<List<FavoriteRecipe>> {
  bool isSaved(String recipeId) =>
      settledValue?.any((f) => f.recipeId == recipeId) ?? false;
}

final recipeFavoritesProvider =
    AsyncNotifierProvider<RecipeFavoritesNotifier, List<FavoriteRecipe>>(
      RecipeFavoritesNotifier.new,
      retry: noRetry,
    );

/// What the entries say about ingredients; none until the insights settled.
final rankingSignalsProvider = Provider<RankingSignals>(
  (ref) => RankingSignals.of(ref.watch(insightsProvider).settledValue),
);

/// The collection, as loading while it reloads (e.g. for another user):
/// the data it still holds may be the previous user's.
AsyncValue<List<Recipe>> _settledCollection(Ref ref) {
  final collection = ref.watch(recipeCollectionProvider);
  return collection.hasValue && collection.isLoading
      ? const AsyncLoading()
      : collection;
}

/// The profile's intolerances against core's table, resolved once for all
/// recipes. Watches only the intolerances, and an equal result notifies
/// nobody, so other profile writes don't re-rank.
final userIntolerancesProvider = Provider<UserIntolerances>(
  (ref) => UserIntolerances(
    ref.watch(intoleranceRulesProvider).value,
    ref.watch(profileProvider.select((p) => p.value?.intolerances)),
  ),
);

/// The collection for this user: their diet applied, ranked, each recipe
/// with its fit.
final rankedRecipesProvider = Provider<AsyncValue<RankedRecipes>>((ref) {
  final diet = ref.watch(profileProvider.select((p) => p.value?.diet));
  final user = ref.watch(userIntolerancesProvider);
  final signals = ref.watch(rankingSignalsProvider);
  return _settledCollection(ref).whenData(
    (recipes) => rankRecipes(recipes, diet: diet, user: user, signals: signals),
  );
});

/// The collection recipe [id]; null for an unknown id. Loading while the
/// collection reloads, like the ranking.
final collectionRecipeProvider = Provider.autoDispose
    .family<AsyncValue<Recipe?>, String>(
      (ref, id) => _settledCollection(ref).whenData((recipes) {
        for (final recipe in recipes) {
          if (recipe.id == id) return recipe;
        }
        return null;
      }),
    );

/// How the recipe [id] fits the user, diet ignored; null for an unknown id.
final recipeFitProvider = Provider.autoDispose
    .family<AsyncValue<RecipeFit?>, String>((ref, id) {
      final user = ref.watch(userIntolerancesProvider);
      return ref
          .watch(collectionRecipeProvider(id))
          .whenData((recipe) => recipe == null ? null : user.fit(recipe));
    });

/// „Für dich" on the collection's page.
final forYouRecipesProvider = Provider<AsyncValue<List<RecipeFit>>>(
  (ref) => ref
      .watch(rankedRecipesProvider)
      .whenData((ranked) => pickForYou(ranked.fits)),
);

/// The saved recipes still in the collection, newest saved first; empty
/// while either list has no data.
final savedRecipesProvider = Provider<List<SavedRecipe>>((ref) {
  final recipes = ref.watch(recipeCollectionProvider).settledValue;
  final favorites = ref.watch(recipeFavoritesProvider).settledValue;
  if (recipes == null || favorites == null) return const [];
  final byId = {for (final r in recipes) r.id: r};
  return [
    for (final f in [...favorites]..sort((a, b) => b.at.compareTo(a.at)))
      if (byId[f.recipeId] case final recipe?) SavedRecipe(recipe, f.at),
  ];
});

/// „Meine Rezepte": own and saved recipes together, newest first. Waits on
/// the own recipes only; saved ones join when they are there.
final myRecipeItemsProvider = Provider<AsyncValue<List<MyRecipeItem>>>((ref) {
  final saved = ref.watch(savedRecipesProvider);
  return ref
      .watch(userRecipesProvider)
      .whenData((own) => mergeMyRecipes(own, saved));
});
