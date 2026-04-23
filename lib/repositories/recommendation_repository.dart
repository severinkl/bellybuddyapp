import 'package:flutter_riverpod/flutter_riverpod.dart';
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
