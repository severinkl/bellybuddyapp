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

  /// [results] that contain [query], without duplicates (by id), best
  /// matches first, at most [limit]: the exact name, then names starting
  /// with it, then names with a word starting with it, then any other name
  /// containing it (ignoring case). Within each, shorter names first, then
  /// by name.
  static List<IngredientSearchResult> rank(
    Iterable<IngredientSearchResult> results, {
    required String query,
    required int limit,
  }) {
    final q = query.trim().toLowerCase();
    final wordStart = RegExp('(^|[\\s\\-(/])${RegExp.escape(q)}');
    int tier(IngredientSearchResult r) {
      final name = r.name.toLowerCase();
      if (name == q) return 0;
      if (name.startsWith(q)) return 1;
      if (wordStart.hasMatch(name)) return 2;
      return 3;
    }

    final matches = {
      for (final r in results)
        if (r.name.toLowerCase().contains(q)) r.id: r,
    }.values.toList();
    matches.sort((a, b) {
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byLength = a.name.length.compareTo(b.name.length);
      if (byLength != 0) return byLength;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matches.take(limit).toList();
  }
}
