import 'package:freezed_annotation/freezed_annotation.dart';
import 'recommendation_item.dart';

part 'recommendation.freezed.dart';
part 'recommendation.g.dart';

/// One of four user-feedback states for a recommendation. Stored on the DB
/// row as the `state` column (TEXT with a CHECK constraint).
enum RecommendationState {
  unrated('unrated'),
  liked('liked'),
  disliked('disliked'),
  hidden('hidden');

  const RecommendationState(this.dbValue);

  final String dbValue;

  static RecommendationState fromDbValue(String? value) {
    if (value == null) return RecommendationState.unrated;
    for (final s in RecommendationState.values) {
      if (s.dbValue == value) return s;
    }
    return RecommendationState.unrated;
  }
}

List<RecommendationItem> _parseItems(List<dynamic>? items) {
  if (items == null) return [];
  return items
      .whereType<Map<String, dynamic>>()
      .map((e) => RecommendationItem.fromJson(e))
      .toList();
}

RecommendationState _stateFromJson(String? v) =>
    RecommendationState.fromDbValue(v);
String _stateToJson(RecommendationState s) => s.dbValue;

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
    @JsonKey(fromJson: _stateFromJson, toJson: _stateToJson)
    @Default(RecommendationState.unrated)
    RecommendationState state,
    @JsonKey(name: 'dislike_category') String? dislikeCategory,
    @JsonKey(name: 'dislike_comment') String? dislikeComment,
    @JsonKey(name: 'rated_at') DateTime? ratedAt,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}
