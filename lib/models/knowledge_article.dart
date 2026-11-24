import 'package:flutter/foundation.dart';

/// One article of the myfodmap blog, as shown in the Wissen feed.
@immutable
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.title,
    required this.link,
    this.category,
    this.publishedAt,
    this.imageUrl,
  });

  final String title;
  final Uri link;
  final String? category;

  /// UTC.
  final DateTime? publishedAt;
  final String? imageUrl;

  Map<String, Object?> toJson() => {
    'title': title,
    'link': link.toString(),
    'category': category,
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'imageUrl': imageUrl,
  };

  /// Throws [FormatException] on any other shape than [toJson]'s.
  factory KnowledgeArticle.fromJson(Map<String, Object?> json) =>
      switch (json) {
        {
          'title': final String title,
          'link': final String link,
          'category': final String? category,
          'publishedAt': final String? publishedAt,
          'imageUrl': final String? imageUrl,
        } =>
          KnowledgeArticle(
            title: title,
            link: Uri.parse(link),
            category: category,
            publishedAt: publishedAt == null
                ? null
                : DateTime.parse(publishedAt).toUtc(),
            imageUrl: imageUrl,
          ),
        _ => throw const FormatException('Invalid KnowledgeArticle JSON'),
      };

  @override
  bool operator ==(Object other) =>
      other is KnowledgeArticle &&
      other.title == title &&
      other.link == link &&
      other.category == category &&
      other.publishedAt == publishedAt &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(title, link, category, publishedAt, imageUrl);
}

/// The parsed blog feed, newest article first.
@immutable
class KnowledgeFeed {
  const KnowledgeFeed({
    required this.articles,
    required this.fetchedAt,
    this.offline = false,
  });

  final List<KnowledgeArticle> articles;
  final DateTime fetchedAt;

  /// Shown from the cache after a failed fetch; not persisted.
  final bool offline;

  /// Distinct categories in order of first appearance.
  List<String> get categories => {
    for (final a in articles)
      if (a.category != null) a.category!,
  }.toList();

  KnowledgeFeed copyWith({bool? offline}) => KnowledgeFeed(
    articles: articles,
    fetchedAt: fetchedAt,
    offline: offline ?? this.offline,
  );

  Map<String, Object?> toJson() => {
    'articles': [for (final a in articles) a.toJson()],
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };

  /// Throws [FormatException] on any other shape than [toJson]'s.
  factory KnowledgeFeed.fromJson(Map<String, Object?> json) => switch (json) {
    {
      'articles': final List<Object?> articles,
      'fetchedAt': final String fetchedAt,
    } =>
      KnowledgeFeed(
        articles: [
          for (final a in articles)
            switch (a) {
              final Map<String, Object?> a => KnowledgeArticle.fromJson(a),
              _ => throw const FormatException('Invalid KnowledgeArticle JSON'),
            },
        ],
        fetchedAt: DateTime.parse(fetchedAt).toUtc(),
      ),
    _ => throw const FormatException('Invalid KnowledgeFeed JSON'),
  };
}
