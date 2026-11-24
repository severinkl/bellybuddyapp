import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/knowledge/knowledge_feed_parser.dart';

/// [_item]'s default link: the blog's address for its title.
const _titleLink = 'title-link';

String _item({
  String title = 'Die Zeitumstellung',
  String? link = _titleLink,
  String? category = ' Gesund verdauen',
  String? pubDate = 'Thu, 27 Mar 2025 23:00:00 GMT',
  String? enclosure = 'https://static.wixstatic.com/media/file.png',
}) =>
    '<item><title><![CDATA[$title]]></title>'
    '${switch (link) {
      null => '',
      _titleLink => '<link>https://www.myfodmap.at/${title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}</link>',
      _ => '<link>$link</link>',
    }}'
    '${category == null ? '' : '<category><![CDATA[$category]]></category>'}'
    '${pubDate == null ? '' : '<pubDate>$pubDate</pubDate>'}'
    '${enclosure == null ? '' : '<enclosure url="$enclosure" type="image/png"/>'}'
    '</item>';

String _feed(List<String> items) =>
    '<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel>'
    '<title>Blog</title>${items.join()}</channel></rss>';

void main() {
  test('reads title, link, category, date and image', () {
    final a = parseKnowledgeFeed(_feed([_item()])).single;
    expect(a.title, 'Die Zeitumstellung');
    expect(a.category, 'Gesund verdauen');
    expect(a.publishedAt, DateTime.utc(2025, 3, 27, 23));
    expect(a.imageUrl, 'https://static.wixstatic.com/media/file.png');
    expect(a.link, Uri.parse('https://www.myfodmap.at/die-zeitumstellung'));
  });

  test('decodes entities left inside CDATA', () {
    final a = parseKnowledgeFeed(
      _feed([
        _item(title: 'No-Bake Lemon Cheesecake - Glutenfrei &#38; low FODMAP'),
      ]),
    ).single;
    expect(a.title, 'No-Bake Lemon Cheesecake - Glutenfrei & low FODMAP');
  });

  test('normalizes categories', () {
    expect(normalizeFeedCategory('❤️ Persönliches'), 'Persönliches');
    expect(normalizeFeedCategory('  Rezepte '), 'Rezepte');
    expect(normalizeFeedCategory('   '), isNull);
    expect(normalizeFeedCategory(null), isNull);
    final a = parseKnowledgeFeed(_feed([_item(category: null)])).single;
    expect(a.category, isNull);
    final b = parseKnowledgeFeed(
      _feed([_item(category: '❤️ Persönliches')]),
    ).single;
    expect(b.category, 'Persönliches');
  });

  test('skips unusable items', () {
    final articles = parseKnowledgeFeed(
      _feed([
        _item(title: 'nolink', link: null),
        _item(title: ''),
        _item(title: 'js', link: 'javascript:alert(1)'),
        _item(title: 'ftp', link: 'ftp://x'),
        _item(title: 'badimg', enclosure: 'ftp://x/a.png'),
        _item(title: 'baddate', pubDate: 'gestern'),
      ]),
    );
    expect(articles.map((a) => a.title), ['badimg', 'baddate']);
    expect(articles[0].imageUrl, isNull);
    expect(articles[1].publishedAt, isNull);
  });

  test('skips links without a host', () {
    final articles = parseKnowledgeFeed(
      _feed([
        _item(title: 'nohost', link: 'https:///blog/post'),
        _item(title: 'path', link: 'https:blog/post'),
        _item(title: 'ok'),
      ]),
    );
    expect(articles.map((a) => a.title), ['ok']);
  });

  test('sorts newest first, undated last', () {
    final articles = parseKnowledgeFeed(
      _feed([
        _item(title: 'B', pubDate: 'Mon, 01 Jan 2024 10:00:00 GMT'),
        _item(title: 'A', pubDate: 'Wed, 01 Jan 2025 10:00:00 GMT'),
        _item(title: 'C', pubDate: null),
      ]),
    );
    expect(articles.map((a) => a.title), ['A', 'B', 'C']);
  });

  test('articles of the same date keep the feed\'s order', () {
    const sameDay = 'Mon, 01 Jan 2024 10:00:00 GMT';
    final articles = parseKnowledgeFeed(
      _feed([
        for (final title in ['D', 'A', 'C', 'B'])
          _item(title: title, pubDate: sameDay),
        _item(title: 'neu', pubDate: 'Wed, 01 Jan 2025 10:00:00 GMT'),
        for (final title in ['Y', 'X']) _item(title: title, pubDate: null),
      ]),
    );
    expect(articles.map((a) => a.title), ['neu', 'D', 'A', 'C', 'B', 'Y', 'X']);
  });

  test('an article listed twice shows once, the newest', () {
    const link = 'https://www.myfodmap.at/suppe';
    final articles = parseKnowledgeFeed(
      _feed([
        _item(
          title: 'Suppe',
          link: link,
          pubDate: 'Mon, 01 Jan 2024 10:00:00 GMT',
        ),
        _item(title: 'Andere', pubDate: null),
        _item(
          title: 'Suppe neu',
          link: link,
          pubDate: 'Wed, 01 Jan 2025 10:00:00 GMT',
        ),
        _item(title: 'Suppe undatiert', link: link, pubDate: null),
      ]),
    );
    expect(articles.map((a) => a.title), ['Suppe neu', 'Andere']);
  });

  test('an empty channel is no error', () {
    expect(parseKnowledgeFeed('<rss><channel></channel></rss>'), isEmpty);
  });

  test('items none of which is usable throw FormatException (the last good '
      'copy stays)', () {
    expect(
      () => parseKnowledgeFeed(
        _feed([_item(title: 'nolink', link: null), _item(title: '')]),
      ),
      throwsFormatException,
    );
  });

  test('truncated XML throws FormatException', () {
    final xml = _feed([_item(), _item()]);
    final cut = xml.substring(0, xml.indexOf('<pubDate>') + 20);
    expect(() => parseKnowledgeFeed(cut), throwsFormatException);
  });

  test('not RSS throws FormatException', () {
    expect(
      () => parseKnowledgeFeed('<html><body>Wartung</body></html>'),
      throwsFormatException,
    );
  });
}
