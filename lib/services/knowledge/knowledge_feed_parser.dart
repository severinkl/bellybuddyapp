import 'dart:io';

import 'package:xml/xml.dart';

import '../../models/knowledge_article.dart';
import '../../utils/url_utils.dart';

/// Parses the myfodmap blog RSS 2.0 feed into articles, newest first
/// (undated last). Unusable items are skipped. Throws [FormatException] when
/// [xml] is not a well-formed RSS document.
List<KnowledgeArticle> parseKnowledgeFeed(String xml) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw FormatException('Invalid feed XML: ${e.message}');
  }
  final channel = doc.rootElement.name.local == 'rss'
      ? doc.rootElement.getElement('channel')
      : null;
  if (channel == null) {
    throw const FormatException('Not an RSS feed');
  }

  final articles = <KnowledgeArticle>[];
  for (final item in channel.findElements('item')) {
    final article = _parseItem(item);
    if (article != null) articles.add(article);
  }

  // List.sort is not stable; order by (date desc, original index).
  final indexed = [for (var i = 0; i < articles.length; i++) (i, articles[i])];
  indexed.sort((x, y) {
    final dx = x.$2.publishedAt;
    final dy = y.$2.publishedAt;
    if (dx != null && dy != null) {
      final c = dy.compareTo(dx);
      if (c != 0) return c;
    } else if (dx != null) {
      return -1;
    } else if (dy != null) {
      return 1;
    }
    return x.$1.compareTo(y.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Trims [raw] and strips leading emoji/symbols; null when nothing is left.
String? normalizeFeedCategory(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.trim().replaceFirst(
    RegExp(r'^[^\p{L}\p{N}]+', unicode: true),
    '',
  );
  return cleaned.isEmpty ? null : cleaned;
}

KnowledgeArticle? _parseItem(XmlElement item) {
  final title = _text(item.getElement('title'));
  final link = _httpUri(_text(item.getElement('link')));
  if (title == null || link == null) return null;

  final image = item.getElement('enclosure')?.getAttribute('url')?.trim();
  return KnowledgeArticle(
    title: title,
    link: link,
    category: normalizeFeedCategory(_text(item.getElement('category'))),
    publishedAt: _date(_text(item.getElement('pubDate'))),
    imageUrl: image != null && image.isNotEmpty && isValidImageUrl(image)
        ? image
        : null,
  );
}

String? _text(XmlElement? e) {
  if (e == null) return null;
  final text = const XmlDefaultEntityMapping.html5().decode(e.innerText).trim();
  return text.isEmpty ? null : text;
}

Uri? _httpUri(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  return uri;
}

DateTime? _date(String? raw) {
  if (raw == null) return null;
  try {
    return HttpDate.parse(raw).toUtc();
  } on HttpException {
    return null;
  } on FormatException {
    return null;
  }
}
