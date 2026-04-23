import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dislike_category.dart';
import '../models/recommendation.dart';
import '../services/recommendation_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecommendationRepository {
  final RecommendationService _recommendationService;
  static const _log = AppLogger('RecommendationRepository');

  RecommendationRepository(this._recommendationService);

  Future<int> countUnseen(String userId) =>
      _recommendationService.countUnseen(userId);

  Future<void> markAllAsSeen(String userId) =>
      _recommendationService.markAllAsSeen(userId);

  Future<List<Recommendation>> fetchByUserId(String userId) => retryAsync(
    () async {
      final rows = await _recommendationService.fetchByUserId(userId);
      // Defense-in-depth: the service applies `.neq('state', 'hidden')` at
      // the SQL layer, but we also drop any hidden rows that slip through so
      // disliked-then-hidden recommendations never surface.
      return rows.where((r) => r.state != RecommendationState.hidden).toList();
    },
    log: _log,
    label: 'fetchByUserId',
  );

  Future<void> updateFeedback({
    required String id,
    required RecommendationState state,
    DislikeCategory? dislikeCategory,
    String? dislikeComment,
  }) async {
    try {
      await _recommendationService.updateFeedback(
        id: id,
        state: state,
        dislikeCategory: dislikeCategory,
        dislikeComment: dislikeComment,
      );
    } catch (e, st) {
      _log.error('updateFeedback failed for id=$id', e, st);
      rethrow;
    }
  }
}

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(ref.watch(recommendationServiceProvider)),
);
