import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../models/user_profile.dart';
import '../services/edge_function_service.dart';
import '../services/recommendation_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecommendationRepository {
  final RecommendationService _recommendationService;
  final EdgeFunctionService _edgeFunctionService;
  static const _log = AppLogger('RecommendationRepository');

  RecommendationRepository(
    this._recommendationService,
    this._edgeFunctionService,
  );

  Future<List<Recommendation>> fetchByUserId(String userId) => retryAsync(
    () => _recommendationService.fetchByUserId(userId),
    log: _log,
    label: 'fetchByUserId',
  );

  Future<List<Recommendation>> refreshRecommendations(
    String userId,
    UserProfile? profile,
  ) async {
    final context = await _recommendationService.fetchRecentContext(userId);

    final body = <String, dynamic>{
      if (profile != null) ...{
        'symptoms': profile.symptoms,
        'intolerances': profile.intolerances,
        'diet': profile.diet,
      },
      ...context,
    };

    await _edgeFunctionService.invoke('diet-recommendations', body: body);

    return _recommendationService.fetchByUserId(userId);
  }
}

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(
    ref.watch(recommendationServiceProvider),
    ref.watch(edgeFunctionServiceProvider),
  ),
);
