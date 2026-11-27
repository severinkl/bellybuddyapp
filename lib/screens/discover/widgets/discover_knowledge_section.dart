import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/knowledge_article.dart';
import '../../../services/knowledge/knowledge_matcher.dart';
import 'discover_section.dart';
import 'knowledge_article_tile.dart';

/// [shown] blog articles and „Alle ›": the „Für dich" [picks] first, each
/// with its reason, then the newest others; none: a line and no link.
class DiscoverKnowledgeSection extends StatelessWidget {
  const DiscoverKnowledgeSection({
    super.key,
    required this.feed,
    required this.onOpenAll,
    required this.onOpen,
    this.picks = const [],
  });

  /// The section, with its „Alle ›".
  static const sectionKey = Key('discover_knowledge');

  /// How many articles the section lists.
  static const shown = 3;

  final AsyncValue<KnowledgeFeed> feed;
  final VoidCallback onOpenAll;
  final ValueChanged<KnowledgeArticle> onOpen;

  /// The „Für dich" articles, from the feed.
  final List<ForYouPick> picks;

  @override
  Widget build(BuildContext context) {
    final articles = feed.value?.articles;
    final hasAny = articles != null && articles.isNotEmpty;
    return DiscoverSection(
      key: sectionKey,
      title: 'Wissen',
      actions: [if (hasAny) DiscoverAllLink(onTap: onOpenAll)],
      child: switch (articles) {
        null => DiscoverNote.pending(feed, 'Artikel'),
        [] => const DiscoverNote('Gerade keine Artikel.'),
        final items => DiscoverListCard(
          children: [
            for (final (article, reason) in _shownOf(items))
              KnowledgeArticleTile(
                article: article,
                reason: reason,
                onTap: () => onOpen(article),
              ),
          ],
        ),
      },
    );
  }

  /// The picks with their reasons, then the newest non-picked [items], up
  /// to [shown] in all.
  Iterable<(KnowledgeArticle, String?)> _shownOf(List<KnowledgeArticle> items) {
    final picked = {for (final p in picks) p.article.link};
    return [
      for (final p in picks) (p.article, p.reason),
      for (final a in items)
        if (!picked.contains(a.link)) (a, null),
    ].take(shown);
  }
}
