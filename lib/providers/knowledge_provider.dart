import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/knowledge_article.dart';
import '../repositories/knowledge_repository.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'buddy_provider.dart';

/// The blog feed behind Wissen: the cached copy while it is fresh, else a
/// fetch. When a fetch fails the last good copy stays, marked offline.
class KnowledgeFeedNotifier extends AsyncNotifier<KnowledgeFeed> {
  static const _log = AppLogger('KnowledgeFeed');

  KnowledgeRepository get _repo => ref.read(knowledgeRepositoryProvider);

  DateTime _now() => ref.read(buddyClockProvider)();

  bool _isFresh(KnowledgeFeed feed, DateTime now) {
    final age = now.difference(feed.fetchedAt);
    return !age.isNegative && age < AppConstants.knowledgeFeedMaxAge;
  }

  @override
  Future<KnowledgeFeed> build() async {
    final now = _now();
    final cache = await _repo.readCache();
    if (cache != null && _isFresh(cache, now)) return cache;
    try {
      return await _fetch(now);
    } on Object catch (e, st) {
      _log.error('Feed fetch failed', e, st);
      if (cache == null) rethrow;
      return cache.copyWith(offline: true);
    }
  }

  Future<KnowledgeFeed> _fetch(DateTime now) async {
    final articles = await _repo.fetchArticles();
    final feed = KnowledgeFeed(articles: articles, fetchedAt: now);
    try {
      await _repo.writeCache(feed);
    } on Object catch (e, st) {
      _log.error('Feed cache write failed', e, st);
    }
    return feed;
  }

  /// Fetches now. A failure keeps the current articles, marked offline.
  /// Never throws.
  Future<void> refresh() async {
    final KnowledgeFeed feed;
    try {
      feed = await _fetch(_now());
    } on Object catch (e, st) {
      _log.error('Feed refresh failed', e, st);
      if (!ref.mounted) return;
      final current = state.value;
      state = current == null
          ? AsyncError(e, st)
          : AsyncData(current.copyWith(offline: true));
      return;
    }
    if (ref.mounted) state = AsyncData(feed);
  }

  /// [refresh]es when the shown copy is [AppConstants.knowledgeFeedMaxAge]
  /// old or older. Nothing while [build] runs: it shows the cached copy
  /// while fresh and fetches otherwise.
  Future<void> refreshIfStale() async {
    if (state.isLoading) return;
    final current = state.value;
    if (current != null && _isFresh(current, _now())) return;
    await refresh();
  }
}

final knowledgeFeedProvider =
    AsyncNotifierProvider<KnowledgeFeedNotifier, KnowledgeFeed>(
      KnowledgeFeedNotifier.new,
      retry: noRetry,
    );
