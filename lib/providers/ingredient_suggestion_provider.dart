import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion.dart';
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

      final data = await SupabaseService.client
          .from('ingredient_suggestions')
          .select('*, ingredients(name)')
          .eq('user_id', userId)
          .isFilter('dismissed_at', null)
          .order('created_at', ascending: false);

      state = AsyncValue.data(
        (data as List).map((e) {
          final ingredientName =
              (e['ingredients'] as Map<String, dynamic>?)?['name'] as String?;
          e['ingredient_name'] = ingredientName;
          return IngredientSuggestion.fromJson(e);
        }).where((s) => s.ingredientId != null).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> dismissSuggestion(String id) async {
    await SupabaseService.client
        .from('ingredient_suggestions')
        .update({'dismissed_at': DateTime.now().toIso8601String()})
        .eq('id', id);

    state = state.whenData(
      (suggestions) => suggestions.where((s) => s.id != id).toList(),
    );
  }

  Future<void> markSeen(String id) async {
    await SupabaseService.client
        .from('ingredient_suggestions')
        .update({'seen_at': DateTime.now().toIso8601String()})
        .eq('id', id);
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
