import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/knowledge_provider.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

void main() {
  var now = DateTime(2026, 11, 23, 10);

  KnowledgeFeed copyAt(DateTime at) => KnowledgeFeed(
    articles: testKnowledgeArticles().sublist(1),
    fetchedAt: at,
  );

  ProviderContainer container(FakeKnowledgeRepository repo) =>
      ProviderContainer.test(
        overrides: [
          knowledgeRepositoryProvider.overrideWithValue(repo),
          buddyClockProvider.overrideWithValue(() => now),
        ],
      );

  setUp(() => now = DateTime(2026, 11, 23, 10));

  test('a fresh copy (< 6 h) is shown without a fetch', () async {
    final repo = FakeKnowledgeRepository(
      cache: copyAt(DateTime(2026, 11, 23, 5)),
    );
    final feed = await container(repo).read(knowledgeFeedProvider.future);
    expect(repo.fetchCount, 0);
    expect(feed.offline, isFalse);
  });

  test('a copy of exactly 6 h is fetched again', () async {
    final repo = FakeKnowledgeRepository(
      cache: copyAt(DateTime(2026, 11, 23, 4)),
    );
    await container(repo).read(knowledgeFeedProvider.future);
    expect(repo.fetchCount, 1);
    expect(repo.written.single.fetchedAt, now);
  });

  test('stale copy, fetch fails: the copy shows, offline', () async {
    final cache = copyAt(DateTime(2026, 11, 22, 4));
    final repo = FakeKnowledgeRepository(cache: cache)
      ..fetchError = Exception('down');
    final feed = await container(repo).read(knowledgeFeedProvider.future);
    expect(feed.offline, isTrue);
    expect(feed.articles, cache.articles);
  });

  test('no copy, fetch fails: error', () async {
    final repo = FakeKnowledgeRepository()..fetchError = Exception('down');
    final c = container(repo);
    await expectLater(c.read(knowledgeFeedProvider.future), throwsException);
    expect(c.read(knowledgeFeedProvider).hasError, isTrue);
    expect(repo.fetchCount, 1);
  });

  test('a copy from the future is fetched again', () async {
    final repo = FakeKnowledgeRepository(
      cache: copyAt(DateTime(2026, 11, 23, 12)),
    );
    await container(repo).read(knowledgeFeedProvider.future);
    expect(repo.fetchCount, 1);
  });

  test('a malformed feed keeps the last good copy', () async {
    final cache = copyAt(DateTime(2026, 11, 22, 4));
    final repo = FakeKnowledgeRepository(cache: cache)
      ..fetchError = const FormatException();
    final feed = await container(repo).read(knowledgeFeedProvider.future);
    expect(feed.articles, cache.articles);
    expect(repo.written, isEmpty);
  });

  test('refresh fetches even when fresh; a failed refresh keeps the articles '
      'and never throws', () async {
    final repo = FakeKnowledgeRepository(
      cache: copyAt(DateTime(2026, 11, 23, 9)),
    );
    final c = container(repo);
    await c.read(knowledgeFeedProvider.future);
    await c.read(knowledgeFeedProvider.notifier).refresh();
    expect(repo.fetchCount, 1);
    expect(
      c.read(knowledgeFeedProvider).value!.articles,
      testKnowledgeArticles(),
    );

    repo.fetchError = Exception('down');
    await c.read(knowledgeFeedProvider.notifier).refresh();
    final value = c.read(knowledgeFeedProvider).value!;
    expect(value.offline, isTrue);
    expect(value.articles, testKnowledgeArticles());
  });

  test('refreshIfStale during the first load fetches nothing more', () async {
    final repo = FakeKnowledgeRepository(
      cache: copyAt(DateTime(2026, 11, 23, 9)),
    );
    final c = container(repo);
    c.listen(knowledgeFeedProvider, (_, _) {});
    await c.read(knowledgeFeedProvider.notifier).refreshIfStale();
    await c.read(knowledgeFeedProvider.future);

    expect(repo.fetchCount, 0);
  });

  test('refreshIfStale fetches only after 6 h', () async {
    final repo = FakeKnowledgeRepository();
    final c = container(repo);
    await c.read(knowledgeFeedProvider.future);
    expect(repo.fetchCount, 1);
    final notifier = c.read(knowledgeFeedProvider.notifier);

    now = DateTime(2026, 11, 23, 15, 59);
    await notifier.refreshIfStale();
    expect(repo.fetchCount, 1);

    now = DateTime(2026, 11, 23, 16);
    await notifier.refreshIfStale();
    expect(repo.fetchCount, 2);
  });
}
