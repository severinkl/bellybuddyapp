import 'package:freezed_annotation/freezed_annotation.dart';
import 'recommendation_item.dart';

part 'recommendation.freezed.dart';
part 'recommendation.g.dart';

List<RecommendationItem> _parseItems(List<dynamic>? items) {
  if (items == null) return [];
  return items
      .whereType<Map<String, dynamic>>()
      .map((e) => RecommendationItem.fromJson(e))
      .toList();
}

@freezed
abstract class Recommendation with _$Recommendation {
  const factory Recommendation({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    String? summary,
    @JsonKey(fromJson: _parseItems)
    @Default([])
    List<RecommendationItem> recommendations,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}
