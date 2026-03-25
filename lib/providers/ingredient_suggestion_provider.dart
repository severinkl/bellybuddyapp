import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../providers/core_providers.dart';
import '../services/ingredient_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import '../utils/suggestion_helpers.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() =>
      const AsyncValue.loading();

  Future<void> fetchSuggestions() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final ingredientService = ref.read(ingredientServiceProvider);

      final data = await retryAsync(
        () => ingredientService.fetchSuggestions(userId),
        log: _log,
        label: 'fetchSuggestions',
      );

      // Extract all suggestion/meal IDs for batch fetching
      final allSuggestionIds = <String>[];
      final allMealIds = <String>{};
      for (final row in data) {
        final id = row['id'] as String?;
        if (id != null) allSuggestionIds.add(id);
        final mealId = row['meal_id'] as String?;
        if (mealId != null) allMealIds.add(mealId);
      }

      final results = await Future.wait([
        ingredientService.fetchReplacements(allSuggestionIds),
        ingredientService.fetchMealDetails(allMealIds.toList()),
      ]);

      final groups = SuggestionHelpers.buildGroups(
        suggestionData: data,
        replacementsData: results[0],
        mealsData: results[1],
      );

      state = AsyncValue.data(groups);
    } catch (e, st) {
      _log.error('fetchSuggestions failed', e, st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllNewAsSeen() async {
    final groups = state.whenOrNull(data: (g) => g);
    if (groups == null) return;

    final unseenIds = groups
        .where((g) => g.isNew)
        .expand((g) => g.suggestionIds)
        .toList();
    if (unseenIds.isEmpty) return;

    try {
      await ref.read(ingredientServiceProvider).markAllSeen(unseenIds);
      state = AsyncValue.data(
        groups.map((g) => g.isNew ? g.copyWith(isNew: false) : g).toList(),
      );
    } catch (e, st) {
      _log.error('markAllNewAsSeen failed', e, st);
    }
  }

  Future<void> dismissSuggestion(List<String> ids) async {
    try {
      await ref.read(ingredientServiceProvider).dismissSuggestions(ids);
      final idsSet = ids.toSet();
      state = state.whenData(
        (groups) =>
            groups.where((g) => !g.suggestionIds.any(idsSet.contains)).toList(),
      );
    } catch (e, st) {
      _log.error('dismissSuggestion failed', e, st);
    }
  }

  int get newCount {
    return state.whenOrNull(
          data: (groups) => groups.where((g) => g.isNew).length,
        ) ??
        0;
  }
}

final ingredientSuggestionProvider =
    NotifierProvider<
      IngredientSuggestionNotifier,
      AsyncValue<List<IngredientSuggestionGroup>>
    >(IngredientSuggestionNotifier.new);
