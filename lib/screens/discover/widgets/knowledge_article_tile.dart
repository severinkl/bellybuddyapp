import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/knowledge_article.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/url_utils.dart';

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

/// One article in the Wissen list: thumbnail, title, „Rezepte · 13. Mär 2025".
class KnowledgeArticleTile extends StatelessWidget {
  const KnowledgeArticleTile({
    super.key,
    required this.article,
    required this.onTap,
  });

  /// The tile of [a].
  static Key keyFor(KnowledgeArticle a) =>
      ValueKey('knowledge_article_${a.link}');

  final KnowledgeArticle article;
  final VoidCallback onTap;

  String? get _meta {
    final parts = [
      ?article.category,
      if (article.publishedAt != null)
        formatDayMonthYear(article.publishedAt!.toLocal()),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return Semantics(
      button: true,
      child: InkWell(
        key: keyFor(article),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(imageUrl: article.imageUrl),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeBodyLG,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                      ),
                    ),
                    if (meta != null) ...[
                      AppConstants.gap4,
                      Text(meta, style: AppTheme.captionMutedStyle),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  static const _size = AppConstants.knowledgeThumbSize;

  Widget get _fallback => Container(
    width: _size,
    height: _size,
    color: AppTheme.muted,
    child: const Icon(
      Icons.menu_book_outlined,
      color: AppTheme.mutedForeground,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: url == null || !isValidImageUrl(url)
          ? _fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              // The blog's images are 1000 px wide landscapes: decoded as
              // tall as the box, their short side fills it under cover.
              memCacheHeight: (_size * dpr).round(),
              // Still with reduced motion.
              placeholder: (context, _) => Shimmer.fromColors(
                enabled: !MediaQuery.disableAnimationsOf(context),
                baseColor: AppTheme.muted,
                highlightColor: AppTheme.background,
                child: Container(
                  width: _size,
                  height: _size,
                  color: AppTheme.muted,
                ),
              ),
              errorWidget: (_, _, _) => _fallback,
            ),
    );
  }
}
