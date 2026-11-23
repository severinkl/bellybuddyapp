import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';
import '../providers/core_providers.dart';
import '../repositories/recommendation_repository.dart';
import '../utils/logger.dart';

class RecommendationNotifier
    extends Notifier<AsyncValue<List<Recommendation>>> {
  static const _log = AppLogger('RecommendationNotifier');

  /// The sets [markAllAsSeen] stamped, by id, with their stamp. A fetch that
  /// started before the server stored the mark still returns them unseen;
  /// they keep the stamp.
  final _seenLocally = <String, DateTime>{};

  @override
  AsyncValue<List<Recommendation>> build() {
    _seenLocally.clear();
    return const AsyncValue.loading();
  }

  Future<void> fetchRecommendations() async {
    // Only flip to loading when we have no cached data. On re-entry / refresh
    // we keep the previous list visible so the PageView doesn't dismount —
    // remounting resets scroll position to initialPage 0 and the "open
    // on newest" anchor loses its target.
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _log.debug('fetchRecommendations: no user');
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final sets = await ref
          .read(recommendationRepositoryProvider)
          .fetchByUserId(userId);
      if (_isCurrentUser(userId)) state = AsyncValue.data(_keepSeen(sets));
    } catch (e, st) {
      if (_isCurrentUser(userId)) state = AsyncValue.error(e, st);
    }
  }

  /// Whether [userId] is still the signed-in user after an await; what was
  /// fetched for the previous one is dropped.
  bool _isCurrentUser(String userId) =>
      ref.mounted && ref.read(currentUserIdProvider) == userId;

  /// [sets] with the stamps [markAllAsSeen] gave them.
  List<Recommendation> _keepSeen(List<Recommendation> sets) => [
    for (final set in sets)
      switch (_seenLocally[set.id]) {
        final seenAt? when set.seenAt == null => set.copyWith(seenAt: seenAt),
        _ => set,
      },
  ];

  /// Marks every set seen: the loaded ones at once, so „Neu" and whatever
  /// follows [unseenTipSetProvider] go as the Tipps open, then the server's.
  Future<void> markAllAsSeen() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final sets = state.value ?? const <Recommendation>[];
    if (sets.any((s) => s.seenAt == null)) {
      final now = DateTime.now().toUtc();
      for (final set in sets) {
        if (set.seenAt == null) _seenLocally[set.id] = now;
      }
      state = AsyncValue.data(_keepSeen(sets));
    }
    await ref.read(recommendationRepositoryProvider).markAllAsSeen(userId);
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

/// The newest loaded tip set while it is unseen: Home's „Neue Tipps" row,
/// the Entdecken dot and the Buddy's announcement. Null while loading,
/// failed, empty or seen; an older unseen set behind a seen newest one is
/// not new.
final unseenTipSetProvider = Provider<Recommendation?>((ref) {
  final newest = switch (ref.watch(recommendationProvider)) {
    AsyncData(:final value) => value.firstOrNull,
    _ => null,
  };
  return newest != null && newest.seenAt == null ? newest : null;
});
