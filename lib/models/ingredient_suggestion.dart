import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_suggestion.freezed.dart';
part 'ingredient_suggestion.g.dart';

@freezed
abstract class IngredientSuggestion with _$IngredientSuggestion {
  const factory IngredientSuggestion({
    required String id,
    @JsonKey(name: 'ingredient_id') String? ingredientId,
    @JsonKey(name: 'ingredient_name') String? ingredientName,
    String? helptext,
    @JsonKey(name: 'meal_count') @Default(0) int mealCount,
    @JsonKey(name: 'is_new') @Default(false) bool isNew,
    @Default([]) List<String> replacements,
    @JsonKey(name: 'seen_at') DateTime? seenAt,
    @JsonKey(name: 'dismissed_at') DateTime? dismissedAt,
  }) = _IngredientSuggestion;

  factory IngredientSuggestion.fromJson(Map<String, dynamic> json) =>
      _$IngredientSuggestionFromJson(json);
}
