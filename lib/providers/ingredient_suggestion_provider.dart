import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion.dart';
import '../services/ingredient_service.dart';
import '../services/supabase_service.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestion>>> {
  @override
  AsyncValue<List<IngredientSuggestion>> build() => const AsyncValue.loading();

  Future<void> fetchSuggestions() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await IngredientService.fetchSuggestions(userId);

      state = AsyncValue.data(
        data.map((e) {
          final ingredients = e['ingredients'] as Map<String, dynamic>?;
          e['ingredient_name'] = ingredients?['name'] as String?;
          return IngredientSuggestion.fromJson(e);
        }).where((s) => s.ingredientId != null).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> dismissSuggestion(String id) async {
    await IngredientService.dismissSuggestion(id);

    state = state.whenData(
      (suggestions) => suggestions.where((s) => s.id != id).toList(),
    );
  }

  Future<void> markSeen(String id) async {
    await IngredientService.markSuggestionSeen(id);
  }

  int get newCount {
    return state.whenOrNull(
          data: (suggestions) => suggestions.where((s) => s.isNew).length,
        ) ??
        0;
  }
}

final ingredientSuggestionProvider = NotifierProvider<
    IngredientSuggestionNotifier,
    AsyncValue<List<IngredientSuggestion>>>(IngredientSuggestionNotifier.new);
