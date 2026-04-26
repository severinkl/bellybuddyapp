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
  }) => IngredientAutocompleteState(
    suggestions: suggestions ?? this.suggestions,
    searchError: searchError,
  );
}

class IngredientAutocompleteNotifier
    extends Notifier<IngredientAutocompleteState> {
  static const _log = AppLogger('IngredientAutocomplete');

  @override
  IngredientAutocompleteState build() => const IngredientAutocompleteState();

  Future<void> searchIngredients(String query) async {
    if (query.length < 3) {
      state = state.copyWith(suggestions: []);
      return;
    }
    state = state.copyWith(searchError: null);
    try {
      final userId = ref.read(currentUserIdProvider);
      final results = await ref
          .read(ingredientRepositoryProvider)
          .search(query, userId: userId);
      state = state.copyWith(suggestions: results);
    } catch (e, st) {
      _log.error('search failed', e, st);
      state = state.copyWith(searchError: e);
    }
  }

  Future<void> addIngredient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(suggestions: []);
    final userId = ref.read(currentUserIdProvider);
    await ref
        .read(ingredientRepositoryProvider)
        .insertIfNew(trimmed, userId: userId);
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
