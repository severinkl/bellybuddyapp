/// The key an ingredient name matches by: trimmed and lower-cased, empty
/// for a blank name. Recipe lines (`RecipeIngredient.matchKeys`) and the
/// diary's meals (the insights, e.g. `Insights.calmDayIngredients`) both
/// key through it, so a match between them is a real one.
String ingredientKey(String name) => name.trim().toLowerCase();
