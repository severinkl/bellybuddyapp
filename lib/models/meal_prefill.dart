import '../utils/distinct_by_name.dart';
import 'adapted_recipe.dart';
import 'recipe.dart';
import 'user_recipe.dart';

/// What the meal tracker starts with when it is opened from a recipe: the
/// title, the ingredient names and, for an own recipe, its photo.
class MealPrefill {
  const MealPrefill({
    required this.title,
    required this.ingredients,
    this.imageUrl,
  });

  /// An own recipe as it is.
  factory MealPrefill.ofUserRecipe(UserRecipe recipe) => MealPrefill(
    title: recipe.title,
    ingredients: recipe.ingredients,
    imageUrl: recipe.imageUrl,
  );

  /// A collection recipe: its line names (an older recipe: its lines),
  /// trimmed, without blanks and without duplicates (case-insensitive, the
  /// first is kept). No image: the collection's photo is not the user's meal.
  factory MealPrefill.ofRecipe(Recipe recipe) => MealPrefill(
    title: recipe.title,
    ingredients: _distinct(
      recipe.isLegacy
          ? recipe.legacyIngredients
          : recipe.ingredients.map((line) => line.name),
    ),
  );

  /// An adapted recipe: its names, cleaned up as in [MealPrefill.ofRecipe],
  /// and no image.
  factory MealPrefill.ofAdapted(AdaptedRecipe adapted) => MealPrefill(
    title: adapted.title,
    ingredients: _distinct(adapted.ingredients.map((i) => i.name)),
  );

  final String title;
  final List<String> ingredients;
  final String? imageUrl;

  static List<String> _distinct(Iterable<String> names) =>
      distinctByName([for (final name in names) name.trim()], (n) => n);
}
