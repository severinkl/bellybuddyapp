import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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

  Future<void> setRecommendationState({
    required String id,
    required RecommendationState state,
    String? comment,
  }) async {
    final previous = this.state;
    final currentList = previous.value;
    if (currentList == null) return;

    // Optimistic update. When the user transitions off disliked (e.g. to
    // liked), comment is null — the service call below writes that as an
    // explicit null so the server row matches.
    final List<Recommendation> next;
    if (state == RecommendationState.hidden) {
      next = currentList.where((r) => r.id != id).toList();
    } else {
      next = currentList
          .map(
            (r) => r.id == id
                ? r.copyWith(
                    state: state,
                    dislikeComment: comment,
                    ratedAt: DateTime.now().toUtc(),
                  )
                : r,
          )
          .toList();
    }
    this.state = AsyncValue.data(next);

    try {
      await ref
          .read(recommendationRepositoryProvider)
          .updateFeedback(id: id, state: state, dislikeComment: comment);
    } catch (e, st) {
      _log.error('setRecommendationState failed for id=$id', e, st);
      this.state = previous;
      rethrow;
    }
  }

  Future<void> setDislikeComment({required String id, String? comment}) async {
    final previous = state;
    final currentList = previous.value;
    if (currentList == null) return;

    final target = currentList.where((r) => r.id == id).firstOrNull;
    if (target == null) return;
    // Early-return on no-op so repeated debounce firings with an unchanged
    // comment don't fire needless network writes or list rebuilds.
    if (target.dislikeComment == comment) return;

    final next = currentList
        .map(
          (r) => r.id == id
              ? r.copyWith(
                  dislikeComment: comment,
                  ratedAt: DateTime.now().toUtc(),
                )
              : r,
        )
        .toList();
    state = AsyncValue.data(next);

    try {
      await ref
          .read(recommendationRepositoryProvider)
          .updateFeedback(id: id, state: target.state, dislikeComment: comment);
    } catch (e, st) {
      _log.error('setDislikeComment failed for id=$id', e, st);
      state = previous;
      rethrow;
    }
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, AsyncValue<List<Recommendation>>>(
      RecommendationNotifier.new,
    );

/// Whether the "no new recommendations for now" notice has been shown during
/// this app session. In-memory only — it is never persisted, so the notice
/// reappears once per app launch (resets on cold start). Set to `true` by
/// `RecommendationsScreen` the first time the screen is opened in a session.
final recommendationsNoticeSeenProvider = StateProvider<bool>((ref) => false);

final unseenRecommendationCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  return ref.read(recommendationRepositoryProvider).countUnseen(userId);
});
