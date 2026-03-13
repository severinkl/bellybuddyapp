import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe.freezed.dart';
part 'recipe.g.dart';

@freezed
abstract class Recipe with _$Recipe {
  const factory Recipe({
    required String id,
    required String title,
    String? description,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'cook_time') int? cookTime,
    int? servings,
    @Default([]) List<String> ingredients,
    @Default([]) List<String> instructions,
    @Default([]) List<String> tags,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Recipe;

  factory Recipe.fromJson(Map<String, dynamic> json) =>
      _$RecipeFromJson(json);
}
