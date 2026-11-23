import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/services/knowledge/knowledge_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fixtures.dart';

HttpKnowledgeRepository _repo([String body = '']) => HttpKnowledgeRepository(
  KnowledgeFeedService(MockClient((_) async => http.Response(body, 200))),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('writeCache then readCache round-trips', () async {
    final feed = KnowledgeFeed(
      articles: testKnowledgeArticles(),
      fetchedAt: DateTime.utc(2026, 11, 23, 9),
    );
    final repo = _repo();
    await repo.writeCache(feed);
    final read = await repo.readCache();
    expect(read!.articles, feed.articles);
    expect(read.fetchedAt, feed.fetchedAt);
    expect(read.offline, isFalse);
  });

  test('nothing cached reads as none', () async {
    expect(await _repo().readCache(), isNull);
  });

  test('a corrupt cache reads as none', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyKnowledgeFeedCache: '{nope',
    });
    expect(await _repo().readCache(), isNull);
  });

  test('fetchArticles parses the service\'s feed', () async {
    const xml = '''<?xml version="1.0"?>
<rss version="2.0"><channel>
<item><title>Hallo</title><link>https://www.myfodmap.at/hallo</link>
<category>Rezepte</category></item>
</channel></rss>''';
    final articles = await _repo(xml).fetchArticles();
    expect(articles.single.title, 'Hallo');
    expect(articles.single.category, 'Rezepte');
  });
}
