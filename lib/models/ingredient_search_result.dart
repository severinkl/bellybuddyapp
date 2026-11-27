/// A search result from the ingredients table.
/// Distinct from the Freezed `IngredientSuggestion` model in
/// `ingredient_suggestion.dart` which represents trigger detection data.
class IngredientSearchResult {
  final String id;

  /// The canonical name.
  final String name;

  /// The word that matched the search: [name] or one of its other names.
  /// This is what gets added to a meal.
  final String matchedName;
  final bool isOwn;

  const IngredientSearchResult({
    required this.id,
    required this.name,
    required this.matchedName,
    required this.isOwn,
  });

  /// The result is found by another word than its [name] (ignoring case
  /// and outer spaces): the list says „= name" beside it.
  bool get showsCanonicalName =>
      matchedName.trim().toLowerCase() != name.trim().toLowerCase();

  /// [results] whose [matchedName] contains [query], without duplicates (by id), best
  /// matches first, at most [limit]: the exact word, then words starting
  /// with it, then words with a word starting with it, then any other word
  /// containing it (ignoring case). Within each, shorter words first, then
  /// alphabetically.
  static List<IngredientSearchResult> rank(
    Iterable<IngredientSearchResult> results, {
    required String query,
    required int limit,
  }) {
    final q = query.trim().toLowerCase();
    final wordStart = RegExp('(^|[\\s\\-(/])${RegExp.escape(q)}');
    int tier(IngredientSearchResult r) {
      final name = r.matchedName.toLowerCase();
      if (name == q) return 0;
      if (name.startsWith(q)) return 1;
      if (wordStart.hasMatch(name)) return 2;
      return 3;
    }

    final matches = {
      for (final r in results)
        if (r.matchedName.toLowerCase().contains(q)) r.id: r,
    }.values.toList();
    matches.sort((a, b) {
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byLength = a.matchedName.length.compareTo(b.matchedName.length);
      if (byLength != 0) return byLength;
      return a.matchedName.toLowerCase().compareTo(b.matchedName.toLowerCase());
    });
    return matches.take(limit).toList();
  }
}
