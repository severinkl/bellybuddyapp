/// A search result from the ingredients table.
/// Distinct from the Freezed `IngredientSuggestion` model in
/// `ingredient_suggestion.dart` which represents trigger detection data.
class IngredientSearchResult {
  final String id;
  final String name;
  final bool isOwn;

  const IngredientSearchResult({
    required this.id,
    required this.name,
    required this.isOwn,
  });
}
