import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../providers/core_providers.dart';
import '../services/recipe_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecipesState {
  final List<Recipe> allRecipes;
  final List<Recipe> filtered;
  final Set<String> favorites;
  final bool isLoading;
  final String search;
  final Set<String> filters;
  final Object? error;

  const RecipesState({
    this.allRecipes = const [],
    this.filtered = const [],
    this.favorites = const {},
    this.isLoading = true,
    this.search = '',
    this.filters = const {},
    this.error,
  });

  RecipesState copyWith({
    List<Recipe>? allRecipes,
    List<Recipe>? filtered,
    Set<String>? favorites,
    bool? isLoading,
    String? search,
    Set<String>? filters,
    Object? error,
  }) {
    return RecipesState(
      allRecipes: allRecipes ?? this.allRecipes,
      filtered: filtered ?? this.filtered,
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      error: error,
    );
  }
}

class RecipesNotifier extends Notifier<RecipesState> {
  static const _log = AppLogger('RecipesProvider');
  @override
  RecipesState build() {
    _loadAll();
    return const RecipesState();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadRecipes(), _loadFavorites()]);
  }

  Future<void> _loadRecipes() async {
    state = state.copyWith(error: null);
    try {
      final recipeService = ref.read(recipeServiceProvider);
      final recipes = await retryAsync(
        recipeService.fetchAll,
        log: _log,
        label: 'loadRecipes',
      );
      state = state.copyWith(
        allRecipes: recipes,
        filtered: recipes,
        isLoading: false,
      );
      _applyFilters();
    } catch (e) {
      _log.error('failed to load recipes', e);
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> _loadFavorites() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final favorites = await ref
          .read(recipeServiceProvider)
          .fetchFavoriteIds(userId);
      state = state.copyWith(favorites: favorites);
    } catch (e) {
      _log.error('failed to load favorites', e);
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final newFavorites = Set<String>.from(state.favorites);
    final recipeService = ref.read(recipeServiceProvider);
    try {
      if (newFavorites.contains(recipeId)) {
        await recipeService.removeFavorite(userId, recipeId);
        newFavorites.remove(recipeId);
      } else {
        await recipeService.addFavorite(userId, recipeId);
        newFavorites.add(recipeId);
      }
      state = state.copyWith(favorites: newFavorites);
    } catch (e) {
      _log.error('failed to toggle favorite', e);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(search: query);
    _applyFilters();
  }

  void toggleFilter(String tag) {
    final newFilters = Set<String>.from(state.filters);
    if (newFilters.contains(tag)) {
      newFilters.remove(tag);
    } else {
      newFilters.add(tag);
    }
    state = state.copyWith(filters: newFilters);
    _applyFilters();
  }

  void _applyFilters() {
    final filtered = state.allRecipes.where((r) {
      final title = r.title.toLowerCase();
      final tags = r.tags;
      final matchesSearch =
          state.search.isEmpty || title.contains(state.search.toLowerCase());
      final matchesFilters =
          state.filters.isEmpty || state.filters.every((f) => tags.contains(f));
      return matchesSearch && matchesFilters;
    }).toList();
    state = state.copyWith(filtered: filtered);
  }
}

final recipesProvider = NotifierProvider<RecipesNotifier, RecipesState>(
  RecipesNotifier.new,
);
