import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/knowledge_article.dart';
import '../../../widgets/common/bb_card.dart';
import 'discover_section.dart';
import 'knowledge_article_tile.dart';

/// The newest [shown] blog articles and „Alle ›"; none: a line and no link.
class DiscoverKnowledgeSection extends StatelessWidget {
  const DiscoverKnowledgeSection({
    super.key,
    required this.feed,
    required this.onOpenAll,
    required this.onOpen,
  });

  /// The section, with its „Alle ›".
  static const sectionKey = Key('discover_knowledge');

  /// How many articles the section lists.
  static const shown = 3;

  final AsyncValue<KnowledgeFeed> feed;
  final VoidCallback onOpenAll;
  final ValueChanged<KnowledgeArticle> onOpen;

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
        final items => BbCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingXs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, article) in items.take(shown).indexed) ...[
                if (i > 0)
                  const Divider(
                    height: AppConstants.dividerThickness,
                    thickness: AppConstants.dividerThickness,
                    color: AppTheme.border,
                  ),
                KnowledgeArticleTile(
                  article: article,
                  onTap: () => onOpen(article),
                ),
              ],
            ],
          ),
        ),
      },
    );
  }
}
