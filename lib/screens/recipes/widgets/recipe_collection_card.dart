import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recipe.dart';
import '../../../services/recipes/recipe_fit.dart';
import 'fit_badge_view.dart';
import 'recipe_image.dart';

/// The mark on a recipe card's picture.
enum RecipeCardTag { saved, adapted }

/// „Gemerkt" (the heart) or „Angepasst" (the sparkle).
class RecipeTagPill extends StatelessWidget {
  const RecipeTagPill(this.tag, {super.key});

  final RecipeCardTag tag;

  @override
  Widget build(BuildContext context) {
    final saved = tag == RecipeCardTag.saved;
    final color = saved ? AppTheme.foreground : AppTheme.primaryForegroundMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: saved ? Colors.white : AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing6,
          vertical: AppConstants.spacing2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? Icons.favorite : Icons.auto_awesome,
              size: AppConstants.iconSizeXs,
              color: saved ? AppTheme.buddyHeart : color,
            ),
            const SizedBox(width: AppConstants.spacingXs),
            Text(
              saved ? 'Gemerkt' : 'Angepasst',
              style: TextStyle(
                fontSize: AppTheme.fontSizeSM,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A collection recipe as a card: picture with an optional tag, title,
/// „35 Min · Mittag" and how it fits the user.
class RecipeCollectionCard extends StatelessWidget {
  const RecipeCollectionCard({
    super.key,
    required this.recipe,
    this.badge,
    this.tag,
    required this.onTap,
  });

  final Recipe recipe;
  final FitBadge? badge;
  final RecipeCardTag? tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = recipe.listMeta;
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipeImage(recipe: recipe),
                  if (tag != null)
                    Positioned(
                      top: AppConstants.spacingSm,
                      left: AppConstants.spacingSm,
                      child: RecipeTagPill(tag!),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacing12,
                vertical: AppConstants.spacingSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    AppConstants.gap4,
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (badge != null) ...[
                    AppConstants.gap6,
                    FitBadgeView(badge!, small: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
