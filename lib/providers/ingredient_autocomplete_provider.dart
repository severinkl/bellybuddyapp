import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingredient_search_result.dart';
import '../repositories/ingredient_repository.dart';
import '../utils/logger.dart';
import 'core_providers.dart';

class IngredientAutocompleteState {
  final List<IngredientSearchResult> suggestions;
  final Object? searchError;

  const IngredientAutocompleteState({
    this.suggestions = const [],
    this.searchError,
  });

  IngredientAutocompleteState copyWith({
    List<IngredientSearchResult>? suggestions,
    Object? searchError,
    bool clearSearchError = false,
  }) => IngredientAutocompleteState(
    suggestions: suggestions ?? this.suggestions,
    searchError: clearSearchError ? null : (searchError ?? this.searchError),
  );
}

class IngredientAutocompleteNotifier
    extends Notifier<IngredientAutocompleteState> {
  static const _log = AppLogger('IngredientAutocomplete');

  int _searchSeq = 0;

  @override
  IngredientAutocompleteState build() => const IngredientAutocompleteState();

  Future<void> searchIngredients(String query) async {
    if (query.length < 3) {
      _searchSeq++;
      _clearSuggestions();
      return;
    }
    final seq = ++_searchSeq;
    state = state.copyWith(clearSearchError: true);
    try {
      final userId = ref.read(currentUserIdProvider);
      final results = await ref
          .read(ingredientRepositoryProvider)
          .search(query, userId: userId);
      // Drop stale responses: a slow query for an earlier prefix must not
      // clobber a fresher query's results.
      if (seq != _searchSeq) return;
      state = state.copyWith(suggestions: results);
    } catch (e, st) {
      if (seq != _searchSeq) return;
      _log.error('search failed', e, st);
      state = state.copyWith(searchError: e);
    }
  }

  void _clearSuggestions() {
    if (state.suggestions.isEmpty && state.searchError == null) return;
    state = state.copyWith(suggestions: [], clearSearchError: true);
  }

  Future<void> addIngredient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _searchSeq++;
    _clearSuggestions();
    final userId = ref.read(currentUserIdProvider);
    try {
      await ref
          .read(ingredientRepositoryProvider)
          .insertIfNew(trimmed, userId: userId);
    } catch (e, st) {
      _log.error('insertIfNew failed', e, st);
    }
  }

  Future<void> deleteUserIngredient(String id) async {
    await ref.read(ingredientRepositoryProvider).deleteUserIngredient(id);
    state = state.copyWith(
      suggestions: state.suggestions.where((s) => s.id != id).toList(),
    );
  }
}

final ingredientAutocompleteProvider =
    NotifierProvider<
      IngredientAutocompleteNotifier,
      IngredientAutocompleteState
    >(IngredientAutocompleteNotifier.new);
