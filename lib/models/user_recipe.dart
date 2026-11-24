import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_recipe.freezed.dart';
part 'user_recipe.g.dart';

@freezed
abstract class UserRecipe with _$UserRecipe {
  const factory UserRecipe({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String title,
    @Default([]) List<String> ingredients,
    @JsonKey(name: 'image_url') String? imageUrl,
    @Default([]) List<String> instructions,
    @JsonKey(name: 'ingredient_amounts') List<String?>? ingredientAmounts,
    @JsonKey(name: 'adapted_from_recipe_id') String? adaptedFromRecipeId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserRecipe;

  const UserRecipe._();

  /// The amount aligned with `ingredients[index]`, or null when there is
  /// none, the index is out of range or the lists are not aligned.
  String? amountOf(int index) {
    final amounts = ingredientAmounts;
    if (amounts == null || amounts.length != ingredients.length) return null;
    if (index < 0 || index >= amounts.length) return null;
    return amounts[index];
  }

  bool get isAdapted => adaptedFromRecipeId != null;

  factory UserRecipe.fromJson(Map<String, dynamic> json) =>
      _$UserRecipeFromJson(json);
}
