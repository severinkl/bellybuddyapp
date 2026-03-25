import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../providers/profile_provider.dart';
import '../repositories/recommendation_repository.dart';
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
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('fetchRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      final recommendations = await retryAsync(
        () => ref.read(recommendationRepositoryProvider).fetchByUserId(userId),
      );
      state = AsyncValue.data(recommendations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshRecommendations() async {
    state = const AsyncValue.loading();
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('refreshRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      final profile = ref.read(profileProvider).whenOrNull(data: (p) => p);
      final recommendations = await ref
          .read(recommendationRepositoryProvider)
          .refreshRecommendations(userId, profile);
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
