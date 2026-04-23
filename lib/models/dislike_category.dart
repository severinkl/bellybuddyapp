/// Why the user downvoted a recommendation. The DB column (`dislike_category`
/// on `public.recommendations`) is free-text; we keep this enum as the
/// client's source of truth for the known values and only allow the client
/// to write these exact strings.
enum DislikeCategory {
  notRelevant('not_relevant', 'Nicht relevant'),
  dontLikeIngredient('dont_like_ingredient', 'Zutat gefällt mir nicht'),
  dontLikeRecipe('dont_like_recipe', 'Rezept gefällt mir nicht'),
  tooComplicated('too_complicated', 'Zu kompliziert'),
  other('other', 'Anderer Grund');

  const DislikeCategory(this.dbValue, this.label);

  /// Stored in Supabase — do not rename without a migration.
  final String dbValue;

  /// German display label for chips / read-out.
  final String label;

  static DislikeCategory? fromDbValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final c in DislikeCategory.values) {
      if (c.dbValue == value) return c;
    }
    return null;
  }
}
