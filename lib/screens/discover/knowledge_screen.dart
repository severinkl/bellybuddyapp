import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/knowledge_article.dart';
import '../../providers/for_you_provider.dart';
import '../../providers/knowledge_provider.dart';
import '../../services/knowledge/knowledge_matcher.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_chip_selector.dart';
import 'widgets/knowledge_article_tile.dart';

/// Wissen: the myfodmap blog's articles, filtered by category. Under
/// „Alle", the articles „Für dich" (with their reasons) come first, above
/// „Alle Artikel" without them.
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key, this.openUrl = launchUrl});

  static const forYouTitle = 'Für dich';
  static const forYouCaption = 'Ausgewählt nach deinen Einträgen und Angaben.';
  static const allArticlesTitle = 'Alle Artikel';

  /// The chip of [category] (`null`: Alle).
  static Key chipKey(String? category) =>
      ValueKey('knowledge_chip_${category ?? '*'}');

  /// How an article opens; tests pass a fake.
  final UrlOpener openUrl;

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  String? _category;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(knowledgeFeedProvider.notifier).refreshIfStale());
  }

  Future<void> _refresh() => ref.read(knowledgeFeedProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(knowledgeFeedProvider);
    final feed = async.value;
    final picks = ref.watch(forYouProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wissen')),
      body: feed != null
          ? _buildList(feed, picks)
          : async.hasError
          ? BbErrorState(
              message: 'Die Artikel konnten nicht geladen werden.',
              retryLabel: 'Nochmal versuchen',
              mascotAsset: AppConstants.mascotClueless,
              onRetry: () => unawaited(_refresh()),
            )
          : const BbLoadingState(message: 'Laden…'),
    );
  }

  Future<void> _open(KnowledgeArticle article) =>
      markOpenedAndOpen(context, ref, article, open: widget.openUrl);

  Widget _buildList(KnowledgeFeed feed, List<ForYouPick> allPicks) {
    final categories = feed.categories;
    // A category that is gone after a refresh falls back to Alle.
    final category = categories.contains(_category) ? _category : null;
    final picks = category == null ? allPicks : const <ForYouPick>[];
    final picked = {for (final p in picks) p.article.link};
    final articles = [
      for (final a in feed.articles)
        if ((category == null || a.category == category) &&
            !picked.contains(a.link))
          a,
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppConstants.paddingMd,
        children: [
          const Text(
            'Artikel aus dem myfodmap-Blog',
            style: AppTheme.captionMutedStyle,
          ),
          if (feed.offline) ...[
            AppConstants.gap4,
            const Text(
              'Gerade offline – du siehst den zuletzt geladenen Stand.',
              style: AppTheme.captionMutedStyle,
            ),
          ],
          AppConstants.gap12,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in [null, ...categories]) ...[
                  BbFilterChip(
                    key: KnowledgeScreen.chipKey(c),
                    label: c ?? 'Alle',
                    selected: c == category,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                ],
              ],
            ),
          ),
          AppConstants.gap12,
          if (picks.isNotEmpty) ...[
            const _Label(KnowledgeScreen.forYouTitle),
            AppConstants.gap4,
            const Text(
              KnowledgeScreen.forYouCaption,
              style: AppTheme.captionMutedStyle,
            ),
            AppConstants.gap8,
            for (final p in picks)
              KnowledgeArticleTile(
                article: p.article,
                reason: p.reason,
                onTap: () => unawaited(_open(p.article)),
              ),
            AppConstants.gap16,
            const _Label(KnowledgeScreen.allArticlesTitle),
            AppConstants.gap8,
          ],
          if (articles.isEmpty)
            const Padding(
              padding: AppConstants.paddingLg,
              child: Text(
                'Gerade keine Artikel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ),
          for (final a in articles)
            KnowledgeArticleTile(article: a, onTap: () => unawaited(_open(a))),
        ],
      ),
    );
  }
}

/// A heading above a part of the list.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}
