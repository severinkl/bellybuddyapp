import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_suggestion.freezed.dart';
part 'ingredient_suggestion.g.dart';

@freezed
abstract class IngredientSuggestion with _$IngredientSuggestion {
  const factory IngredientSuggestion({
    required String id,
    @JsonKey(name: 'detected_ingredient_id') String? detectedIngredientId,
    @JsonKey(name: 'meal_id') String? mealId,
    String? helptext,
    @JsonKey(name: 'seen_at') DateTime? seenAt,
    @JsonKey(name: 'dismissed_at') DateTime? dismissedAt,
  }) = _IngredientSuggestion;

  factory IngredientSuggestion.fromJson(Map<String, dynamic> json) =>
      _$IngredientSuggestionFromJson(json);
}
