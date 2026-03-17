import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient_suggestion_group.dart';
import '../models/replacement_ingredient.dart';
import '../services/ingredient_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class IngredientSuggestionNotifier
    extends Notifier<AsyncValue<List<IngredientSuggestionGroup>>> {
  static const _log = AppLogger('IngredientSuggestions');

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() =>
      const AsyncValue.loading();

  Future<void> fetchSuggestions() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await retryAsync(
        () => IngredientService.fetchSuggestions(userId),
        log: _log,
        label: 'fetchSuggestions',
      );

      // Group rows by detected_ingredient_id
      final grouped = <String, _GroupAccumulator>{};
      for (final row in data) {
        final ingredientId = row['detected_ingredient_id'] as String?;
        if (ingredientId == null) continue;

        final ingredients = row['ingredients'] as Map<String, dynamic>?;
        final acc = grouped.putIfAbsent(
          ingredientId,
          () => _GroupAccumulator(
            ingredientId: ingredientId,
            ingredientName: ingredients?['name'] as String? ?? 'Unbekannt',
            ingredientImageUrl: ingredients?['image_url'] as String?,
            helptext: row['helptext'] as String?,
          ),
        );
        acc.suggestionIds.add(row['id'] as String);
        final mealId = row['meal_id'] as String?;
        if (mealId != null) acc.mealIds.add(mealId);
        if (row['seen_at'] == null) acc.hasUnseen = true;
      }

      // Batch-fetch replacements and meal details in parallel
      final allSuggestionIds = grouped.values
          .expand((a) => a.suggestionIds)
          .toList();
      final allMealIds = grouped.values
          .expand((a) => a.mealIds)
          .toSet()
          .toList();

      final results = await Future.wait([
        IngredientService.fetchReplacements(allSuggestionIds),
        IngredientService.fetchMealDetails(allMealIds),
      ]);

      final replacementsData = results[0];
      final mealsData = results[1];

      // Build a lookup: suggestion_id → accumulator (for mapping replacements)
      final suggestionToIngredient = <String, String>{};
      for (final acc in grouped.values) {
        for (final sid in acc.suggestionIds) {
          suggestionToIngredient[sid] = acc.ingredientId;
        }
      }

      // Group replacements by ingredient
      final replacementsByIngredient =
          <String, Map<String, ReplacementIngredient>>{};
      for (final row in replacementsData) {
        final suggestionId = row['suggestion_id'] as String;
        final ingredients = row['ingredients'] as Map<String, dynamic>?;
        if (ingredients == null) continue;

        final ingredientId = suggestionToIngredient[suggestionId];
        if (ingredientId == null) continue;

        final replMap = replacementsByIngredient.putIfAbsent(
          ingredientId,
          () => {},
        );
        final replId = ingredients['id'] as String;
        replMap.putIfAbsent(
          replId,
          () => ReplacementIngredient(
            id: replId,
            name: ingredients['name'] as String? ?? '',
            imageUrl: ingredients['image_url'] as String?,
          ),
        );
      }

      // Index meals by id
      final mealsById = <String, MealDetail>{};
      for (final row in mealsData) {
        final id = row['id'] as String;
        mealsById[id] = MealDetail(
          id: id,
          title: row['title'] as String? ?? '',
          trackedAt: DateTime.parse(row['tracked_at'] as String),
          imageUrl: row['image_url'] as String?,
        );
      }

      // Build groups sorted alphabetically by ingredient name
      final groups =
          grouped.values.map((acc) {
            final meals = acc.mealIds
                .map((id) => mealsById[id])
                .whereType<MealDetail>()
                .toList();
            final replacements =
                replacementsByIngredient[acc.ingredientId]?.values.toList() ??
                [];

            return IngredientSuggestionGroup(
              ingredientId: acc.ingredientId,
              ingredientName: acc.ingredientName,
              ingredientImageUrl: acc.ingredientImageUrl,
              helptext: acc.helptext,
              mealCount: acc.mealIds.length,
              isNew: acc.hasUnseen,
              suggestionIds: acc.suggestionIds,
              meals: meals,
              replacements: replacements,
            );
          }).toList()..sort(
            (a, b) => a.ingredientName.toLowerCase().compareTo(
              b.ingredientName.toLowerCase(),
            ),
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
      await IngredientService.markAllSeen(unseenIds);
      state = AsyncValue.data(
        groups.map((g) => g.isNew ? g.copyWith(isNew: false) : g).toList(),
      );
    } catch (e, st) {
      _log.error('markAllNewAsSeen failed', e, st);
    }
  }

  Future<void> dismissSuggestion(List<String> ids) async {
    try {
      await IngredientService.dismissSuggestions(ids);
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

class _GroupAccumulator {
  final String ingredientId;
  final String ingredientName;
  final String? ingredientImageUrl;
  final String? helptext;
  final List<String> suggestionIds = [];
  final Set<String> mealIds = {};
  bool hasUnseen = false;

  _GroupAccumulator({
    required this.ingredientId,
    required this.ingredientName,
    this.ingredientImageUrl,
    this.helptext,
  });
}

final ingredientSuggestionProvider =
    NotifierProvider<
      IngredientSuggestionNotifier,
      AsyncValue<List<IngredientSuggestionGroup>>
    >(IngredientSuggestionNotifier.new);
