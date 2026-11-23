import 'package:freezed_annotation/freezed_annotation.dart';
import '../utils/date_format_utils.dart';
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
    @JsonKey(name: 'dislike_comment') String? dislikeComment,
    @JsonKey(name: 'rated_at') DateTime? ratedAt,

    /// When the user opened the Tipps with this set loaded; null while the
    /// set is new.
    @JsonKey(name: 'seen_at') DateTime? seenAt,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}

/// What the tip-set cards (Home's row, Entdecken's card) say about a set.
extension RecommendationLabels on Recommendation {
  /// „Woche 47": the local ISO week it was made in; null while unknown.
  String? get weekLabel {
    final createdAt = this.createdAt;
    return createdAt == null ? null : 'Woche ${isoWeekOf(createdAt.toLocal())}';
  }

  /// „1 Tipp", „3 Tipps".
  String get tipCountLabel {
    final count = recommendations.length;
    return count == 1 ? '1 Tipp' : '$count Tipps';
  }
}
