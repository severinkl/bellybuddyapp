import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../providers/profile_provider.dart';
import '../services/edge_function_service.dart';
import '../services/recommendation_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class RecommendationNotifier
    extends Notifier<AsyncValue<List<Recommendation>>> {
  static const _log = AppLogger('RecommendationNotifier');

  @override
  AsyncValue<List<Recommendation>> build() => const AsyncValue.loading();

  Future<void> fetchRecommendations() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        _log.debug('fetchRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      final recommendations = await retryAsync(
        () => RecommendationService.fetchByUserId(userId),
      );
      state = AsyncValue.data(recommendations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshRecommendations() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        _log.debug('refreshRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      // Gather user context from profile
      final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
      final context = await RecommendationService.fetchRecentContext(userId);

      final body = <String, dynamic>{
        if (profile != null) ...{
          'symptoms': profile.symptoms,
          'intolerances': profile.intolerances,
          'diet': profile.diet,
        },
        ...context,
      };

      await ref
          .read(edgeFunctionServiceProvider)
          .invoke('diet-recommendations', body: body);
      // Re-fetch to get the newly saved recommendation from DB
      final recommendations = await RecommendationService.fetchByUserId(userId);
      state = AsyncValue.data(recommendations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, AsyncValue<List<Recommendation>>>(
      RecommendationNotifier.new,
    );
