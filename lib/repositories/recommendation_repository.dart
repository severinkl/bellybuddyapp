import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/first_tip.dart';
import '../models/recommendation.dart';
import '../services/recommendation_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecommendationRepository {
  final RecommendationService _recommendationService;
  static const _log = AppLogger('RecommendationRepository');

  RecommendationRepository(this._recommendationService);

  Future<void> markSeen(String userId, List<String> ids) =>
      _recommendationService.markSeen(userId, ids);

  /// The day-3 first tip, asked once: never retried (cost, rate limits).
  Future<FirstTipResult> requestFirstTip({
    required List<String> intolerances,
    required String? diet,
  }) => _recommendationService.requestFirstTip(
    intolerances: intolerances,
    diet: diet,
  );

  Future<List<Recommendation>> fetchByUserId(String userId) => retryAsync(
    () => _recommendationService.fetchByUserId(userId),
    log: _log,
    label: 'fetchByUserId',
  );

  Future<void> updateFeedback({
    required String id,
    required RecommendationState state,
    String? dislikeComment,
  }) async {
    try {
      await _recommendationService.updateFeedback(
        id: id,
        state: state,
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
