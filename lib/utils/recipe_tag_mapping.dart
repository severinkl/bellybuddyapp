/// Maps user intolerances to recipe filter tags.
const Map<String, String> intoleranceToRecipeTag = {
  'Gluten': 'Glutenfrei',
  'Laktose': 'Laktosefrei',
  'Milch': 'Laktosefrei',
};

/// Maps user diet to recipe filter tags.
const Map<String, String> dietToRecipeTag = {
  'vegetarisch': 'Vegetarisch',
  'vegan': 'Vegan',
};

/// Returns the set of recipe tags that should be auto-applied as filters
/// based on the user's diet and intolerances.
Set<String> getAutoRecipeFilters({
  String? diet,
  List<String> intolerances = const [],
}) {
  final tags = <String>{};

  if (diet != null) {
    final tag = dietToRecipeTag[diet];
    if (tag != null) tags.add(tag);
  }

  for (final intolerance in intolerances) {
    final tag = intoleranceToRecipeTag[intolerance];
    if (tag != null) tags.add(tag);
  }

  return tags;
}
