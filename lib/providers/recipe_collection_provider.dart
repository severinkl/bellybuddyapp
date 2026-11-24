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
import 'user_recipes_provider.dart';

const _log = AppLogger('RecipeCollection');
const _favLog = AppLogger('RecipeFavorites');

/// The visible recipe collection; empty while signed out. A failed load
/// stays an error (no automatic retries); [refresh] keeps what is shown.
class RecipeCollectionNotifier extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    return ref.read(recipeRepositoryProvider).fetchCollection();
  }

  /// Fetches again. A failure keeps the data on show (logged); without
  /// data, the error stays.
  Future<void> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final recipes = await ref
          .read(recipeRepositoryProvider)
          .fetchCollection();
      if (ref.isCurrentUser(userId)) state = AsyncData(recipes);
    } catch (e, st) {
      _log.error('refresh failed', e, st);
      if (ref.isCurrentUser(userId) && !state.hasValue) {
        state = AsyncError(e, st);
      }
    }
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
class RecipeFavoritesNotifier extends AsyncNotifier<List<FavoriteRecipe>> {
  @override
  Future<List<FavoriteRecipe>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(recipeRepositoryProvider).fetchFavorites(userId);
  }

  bool isSaved(String recipeId) =>
      state.settledValue?.any((f) => f.recipeId == recipeId) ?? false;

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

  /// Fetches again, keeping the data on show when it fails.
  Future<void> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final favorites = await ref
          .read(recipeRepositoryProvider)
          .fetchFavorites(userId);
      if (ref.isCurrentUser(userId)) state = AsyncData(favorites);
    } catch (e, st) {
      _favLog.error('refresh favourites failed', e, st);
      if (ref.isCurrentUser(userId) && !state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }
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

/// The collection for this user: their diet applied, ranked, each recipe
/// with its fit.
final rankedRecipesProvider = Provider<AsyncValue<RankedRecipes>>((ref) {
  final profile = ref.watch(profileProvider).value;
  final rules = ref.watch(intoleranceRulesProvider).value;
  final signals = ref.watch(rankingSignalsProvider);
  return _settledCollection(ref).whenData(
    (recipes) => rankRecipes(
      recipes,
      diet: profile?.diet,
      rules: rules,
      intolerances: profile?.intolerances,
      signals: signals,
    ),
  );
});

/// How the recipe [id] fits the user, diet ignored; null for an unknown id.
final recipeFitProvider = Provider.family<AsyncValue<RecipeFit?>, String>((
  ref,
  id,
) {
  final profile = ref.watch(profileProvider).value;
  final rules = ref.watch(intoleranceRulesProvider).value;
  return _settledCollection(ref).whenData((recipes) {
    for (final recipe in recipes) {
      if (recipe.id == id) {
        return fitOf(recipe, rules: rules, intolerances: profile?.intolerances);
      }
    }
    return null;
  });
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
