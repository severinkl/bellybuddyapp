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
