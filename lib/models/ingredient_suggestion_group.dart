import 'replacement_ingredient.dart';

class MealDetail {
  final String id;
  final String title;
  final DateTime trackedAt;
  final String? imageUrl;

  const MealDetail({
    required this.id,
    required this.title,
    required this.trackedAt,
    this.imageUrl,
  });
}

class IngredientSuggestionGroup {
  final String ingredientId;
  final String ingredientName;
  final String? ingredientImageUrl;
  final String? helptext;
  final int mealCount;
  final bool isNew;
  final List<String> suggestionIds;
  final List<MealDetail> meals;
  final List<ReplacementIngredient> replacements;

  const IngredientSuggestionGroup({
    required this.ingredientId,
    required this.ingredientName,
    this.ingredientImageUrl,
    this.helptext,
    required this.mealCount,
    required this.isNew,
    required this.suggestionIds,
    this.meals = const [],
    this.replacements = const [],
  });

  /// When the latest of [meals] was eaten; null without meals.
  DateTime? get latestMeal {
    DateTime? latest;
    for (final meal in meals) {
      if (latest == null || meal.trackedAt.isAfter(latest)) {
        latest = meal.trackedAt;
      }
    }
    return latest;
  }

  /// The order of suggestion lists: new groups first; then, with
  /// [latestMealFirst], by [latestMeal], newest first (groups without meals
  /// last); then by ingredient name, ignoring case.
  static int compareNewFirst(
    IngredientSuggestionGroup a,
    IngredientSuggestionGroup b, {
    bool latestMealFirst = false,
  }) {
    if (a.isNew != b.isNew) return a.isNew ? -1 : 1;
    if (latestMealFirst) {
      final la = a.latestMeal;
      final lb = b.latestMeal;
      if (la != lb) {
        if (la == null) return 1;
        if (lb == null) return -1;
        return lb.compareTo(la);
      }
    }
    return a.ingredientName.toLowerCase().compareTo(
      b.ingredientName.toLowerCase(),
    );
  }

  IngredientSuggestionGroup copyWith({
    bool? isNew,
    List<ReplacementIngredient>? replacements,
    List<MealDetail>? meals,
  }) {
    return IngredientSuggestionGroup(
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      ingredientImageUrl: ingredientImageUrl,
      helptext: helptext,
      mealCount: mealCount,
      isNew: isNew ?? this.isNew,
      suggestionIds: suggestionIds,
      meals: meals ?? this.meals,
      replacements: replacements ?? this.replacements,
    );
  }
}
