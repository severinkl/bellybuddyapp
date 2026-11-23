import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/knowledge_article.dart';

KnowledgeArticle _a(String title, {String? category}) => KnowledgeArticle(
  title: title,
  link: Uri.parse('https://www.myfodmap.at/$title'),
  category: category,
);

void main() {
  test('KnowledgeFeed round-trips through JSON without offline', () {
    final feed = KnowledgeFeed(
      articles: [
        KnowledgeArticle(
          title: 'A',
          link: Uri.parse('https://www.myfodmap.at/a'),
          category: 'Rezepte',
          publishedAt: DateTime.utc(2025, 3, 27, 23),
          imageUrl: 'https://static.wixstatic.com/a.png',
        ),
        _a('B'),
      ],
      fetchedAt: DateTime.utc(2026, 1, 2),
    );
    final back = KnowledgeFeed.fromJson(feed.copyWith(offline: true).toJson());
    expect(back.offline, isFalse);
    expect(back.articles, feed.articles);
    expect(back.fetchedAt, feed.fetchedAt);
  });

  test('categories in order of first appearance', () {
    final feed = KnowledgeFeed(
      articles: [
        _a('1', category: 'Rezepte'),
        _a('2', category: 'Gesund verdauen'),
        _a('3', category: 'Rezepte'),
        _a('4'),
      ],
      fetchedAt: DateTime.utc(2026),
    );
    expect(feed.categories, ['Rezepte', 'Gesund verdauen']);
  });

  test('fromJson of a bad shape throws FormatException', () {
    expect(
      () => KnowledgeFeed.fromJson(const {'articles': 3}),
      throwsFormatException,
    );
    expect(() => KnowledgeFeed.fromJson(const {}), throwsFormatException);
  });
}
