/// The key an ingredient name matches by: trimmed and lower-cased, empty
/// for a blank name. The diary's meals (the insights, e.g.
/// `Insights.calmDayIngredients`) key through it; a recipe line is such a
/// food by `RecipeIngredient.isFood` (core's match key or a shared food
/// word, `FoodName`).
String ingredientKey(String name) => name.trim().toLowerCase();
