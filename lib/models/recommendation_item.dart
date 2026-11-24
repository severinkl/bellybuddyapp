class RecommendationItem {
  final String type; // 'substitute' | 'try'
  final String ingredient;
  final String reason;
  final String? alternative;

  /// „Fokus der Woche" (core #12); false on older sets.
  final bool focus;

  /// The collection recipe core matched to a Tausch-Tipp; null on older
  /// sets and when none matched.
  final String? recipeId;

  /// That recipe's title as core saw it; null when unknown.
  final String? recipeTitle;

  const RecommendationItem({
    required this.type,
    required this.ingredient,
    required this.reason,
    this.alternative,
    this.focus = false,
    this.recipeId,
    this.recipeTitle,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) =>
      RecommendationItem(
        type: json['type'] as String? ?? 'try',
        ingredient: json['ingredient'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        alternative: json['alternative'] as String?,
        focus: json['focus'] == true,
        recipeId: _trimmedOrNull(json['recipe_id']),
        recipeTitle: _trimmedOrNull(json['recipe_title']),
      );

  /// An older set's keys, plus the new ones only when set.
  Map<String, dynamic> toJson() => {
    'type': type,
    'ingredient': ingredient,
    'reason': reason,
    if (alternative != null) 'alternative': alternative,
    if (focus) 'focus': true,
    if (recipeId != null) 'recipe_id': recipeId,
    if (recipeTitle != null) 'recipe_title': recipeTitle,
  };

  bool get isSubstitute => type == 'substitute';
  bool get isTry => type == 'try';

  /// Whether the tip links its matching recipe: a Tausch-Tipp with one.
  bool get hasRecipeLink => isSubstitute && recipeId != null;

  static String? _trimmedOrNull(Object? value) {
    final trimmed = value is String ? value.trim() : '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
