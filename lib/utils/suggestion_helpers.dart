import '../models/ingredient_suggestion_group.dart';
import '../models/replacement_ingredient.dart';
import 'url_utils.dart';

class _GroupAccumulator {
  final String ingredientId;

  /// The embedded catalog name; null when row level security hides the
  /// ingredient's row.
  final String? ingredientName;
  final String? ingredientImageUrl;
  final String? helptext;
  final List<String> suggestionIds = [];
  final Set<String> mealIds = {};
  bool hasUnseen = false;

  _GroupAccumulator({
    required this.ingredientId,
    this.ingredientName,
    this.ingredientImageUrl,
    this.helptext,
  });
}

abstract final class SuggestionHelpers {
  /// A group's name when nothing tells which ingredient it is.
  static const unknownIngredient = 'Unbekannte Zutat';

  /// The picture of ingredient [name]: its own ([own]); without one, that
  /// of a replacement that is the same food in a variety („Tofu (fest,
  /// natur)" for „Tofu"); else null (a neutral placeholder shows).
  static String? ingredientImage(
    String name,
    String? own,
    List<ReplacementIngredient> replacements,
  ) {
    if (own != null && isValidImageUrl(own)) return own;
    final food = name.trim().toLowerCase();
    for (final r in replacements) {
      final url = r.imageUrl;
      if (url == null || !isValidImageUrl(url)) continue;
      final other = r.name.trim().toLowerCase();
      if (other == food || other.startsWith('$food (')) return url;
    }
    return null;
  }

  /// The ingredient a suggestion's [helptext] is about, when its catalog
  /// row is hidden: the one of [candidates] (its meals' ingredients) the
  /// text names first, as a word of its own (a German ending allowed:
  /// „Zwiebel" in „Zwiebeln", not „Ei" in „Eiweiß"); else the name before
  /// „enthält" of the server's fallback text („Knoblauch enthält …").
  static String? nameFromHelptext(
    String? helptext,
    Iterable<String> candidates,
  ) {
    if (helptext == null || helptext.trim().isEmpty) return null;
    String? best;
    var bestAt = -1;
    for (final candidate in candidates) {
      final name = candidate.trim();
      if (name.isEmpty) continue;
      final match = RegExp(
        '(?<!\\p{L})${RegExp.escape(name)}(?:e|n|s|en|es|er|ern)?(?!\\p{L})',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(helptext);
      if (match == null) continue;
      final at = match.start;
      if (best == null ||
          at < bestAt ||
          (at == bestAt && name.length > best.length)) {
        best = name;
        bestAt = at;
      }
    }
    if (best != null) return best;
    final fallback = RegExp(r'^(.+?) enthält ').firstMatch(helptext.trim());
    return fallback?.group(1)?.trim();
  }

  /// Transforms raw suggestion rows + replacement rows + meal rows into
  /// grouped, sorted [IngredientSuggestionGroup] list.
  static List<IngredientSuggestionGroup> buildGroups({
    required List<Map<String, dynamic>> suggestionData,
    required List<Map<String, dynamic>> replacementsData,
    required List<Map<String, dynamic>> mealsData,
  }) {
    // Index meals by id
    final mealsById = <String, MealDetail>{};
    for (final row in mealsData) {
      final id = row['id'] as String;
      mealsById[id] = MealDetail(
        id: id,
        title: row['title'] as String? ?? '',
        trackedAt: DateTime.parse(row['tracked_at'] as String),
        imageUrl: row['image_url'] as String?,
        ingredients: [
          for (final name in row['ingredients'] as List? ?? const [])
            if (name is String) name,
        ],
      );
    }

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
          ingredientName: ingredients?['name'] as String?,
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

    // Build groups sorted alphabetically by ingredient name
    final groups =
        grouped.values.map((acc) {
          final meals = acc.mealIds
              .map((id) => mealsById[id])
              .whereType<MealDetail>()
              .toList();
          final replacements =
              replacementsByIngredient[acc.ingredientId]?.values.toList() ?? [];

          final name =
              acc.ingredientName ??
              nameFromHelptext(acc.helptext, [
                for (final meal in meals) ...meal.ingredients,
              ]) ??
              unknownIngredient;

          return IngredientSuggestionGroup(
            ingredientId: acc.ingredientId,
            ingredientName: name,
            ingredientImageUrl: ingredientImage(
              name,
              acc.ingredientImageUrl,
              replacements,
            ),
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
