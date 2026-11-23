import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/knowledge_article.dart';
import '../../providers/knowledge_provider.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_chip_selector.dart';
import 'widgets/knowledge_article_tile.dart';

/// Opens [article] in the in-app browser; a SnackBar says when that fails.
Future<void> openArticle(
  BuildContext context,
  KnowledgeArticle article, {
  UrlOpener open = launchUrl,
}) => openExternalUrl(
  context,
  article.link.toString(),
  failureMessage: 'Der Artikel konnte nicht geöffnet werden.',
  open: open,
  mode: LaunchMode.inAppBrowserView,
);

/// Wissen: the myfodmap blog's articles, filtered by category.
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key, this.openUrl = launchUrl});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Wissen')),
      body: feed != null
          ? _buildList(feed)
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

  Widget _buildList(KnowledgeFeed feed) {
    final categories = feed.categories;
    // A category that is gone after a refresh falls back to Alle.
    final category = categories.contains(_category) ? _category : null;
    final articles = [
      for (final a in feed.articles)
        if (category == null || a.category == category) a,
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppConstants.paddingMd,
        children: [
          const Text(
            'Artikel aus dem myfodmap-Blog',
            style: TextStyle(
              fontSize: AppTheme.fontSizeCaptionLG,
              color: AppTheme.mutedForeground,
            ),
          ),
          if (feed.offline) ...[
            AppConstants.gap4,
            const Text(
              'Gerade offline – du siehst den zuletzt geladenen Stand.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaptionLG,
                color: AppTheme.mutedForeground,
              ),
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
            KnowledgeArticleTile(
              article: a,
              onTap: () =>
                  unawaited(openArticle(context, a, open: widget.openUrl)),
            ),
        ],
      ),
    );
  }
}
