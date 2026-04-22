import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../repositories/recommendation_repository.dart';
import '../utils/logger.dart';

class RecommendationNotifier
    extends Notifier<AsyncValue<List<Recommendation>>> {
  static const _log = AppLogger('RecommendationNotifier');

  @override
  AsyncValue<List<Recommendation>> build() => const AsyncValue.loading();

  Future<void> fetchRecommendations() async {
    // Only flip to loading when we have no cached data. On re-entry / refresh
    // we keep the previous list visible so the PageView doesn't dismount —
    // remounting resets scroll position to initialPage 0 and the "open
    // on newest" anchor loses its target.
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('fetchRecommendations: no user');
        state = const AsyncValue.data([]);
        return;
      }

      final recommendations = await ref
          .read(recommendationRepositoryProvider)
          .fetchByUserId(userId);
      state = AsyncValue.data(recommendations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllAsSeen() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(recommendationRepositoryProvider).markAllAsSeen(userId);
    ref.invalidate(unseenRecommendationCountProvider);
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, AsyncValue<List<Recommendation>>>(
      RecommendationNotifier.new,
    );

final unseenRecommendationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  return ref.read(recommendationRepositoryProvider).countUnseen(userId);
});
