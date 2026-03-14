class RecommendationItem {
  final String type; // 'substitute' | 'try'
  final String ingredient;
  final String reason;
  final String? alternative;

  const RecommendationItem({
    required this.type,
    required this.ingredient,
    required this.reason,
    this.alternative,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) =>
      RecommendationItem(
        type: json['type'] as String? ?? 'try',
        ingredient: json['ingredient'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        alternative: json['alternative'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'ingredient': ingredient,
        'reason': reason,
        if (alternative != null) 'alternative': alternative,
      };

  bool get isSubstitute => type == 'substitute';
  bool get isTry => type == 'try';
}
