/// The key an ingredient name matches by: trimmed and lower-cased, empty
/// for a blank name. The diary's meals (the insights, e.g.
/// `Insights.calmDayIngredients`) key through it; a recipe line is such a
/// food by the same key or a shared food word (`RecipeIngredient.isFood`,
/// `sameFood`).
String ingredientKey(String name) => name.trim().toLowerCase();
