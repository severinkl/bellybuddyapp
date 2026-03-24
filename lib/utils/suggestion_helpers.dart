import '../models/ingredient_suggestion_group.dart';
import '../models/replacement_ingredient.dart';

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

abstract final class SuggestionHelpers {
  /// Transforms raw suggestion rows + replacement rows + meal rows into
  /// grouped, sorted [IngredientSuggestionGroup] list.
  static List<IngredientSuggestionGroup> buildGroups({
    required List<Map<String, dynamic>> suggestionData,
    required List<Map<String, dynamic>> replacementsData,
    required List<Map<String, dynamic>> mealsData,
  }) {
    // Group rows by detected_ingredient_id
    final grouped = <String, _GroupAccumulator>{};
    for (final row in suggestionData) {
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

    // Build lookup: suggestion_id → ingredient_id
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
              replacementsByIngredient[acc.ingredientId]?.values.toList() ?? [];

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

    return groups;
  }
}
