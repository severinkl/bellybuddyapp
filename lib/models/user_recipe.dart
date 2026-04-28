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
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserRecipe;

  factory UserRecipe.fromJson(Map<String, dynamic> json) =>
      _$UserRecipeFromJson(json);
}
