import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/recipe.dart';
import '../../../services/recipes/recipe_fit.dart';
import '../../../widgets/common/bb_card.dart';
import 'fit_badge_view.dart';
import 'recipe_image.dart';

/// A collection recipe as a list row: thumbnail, title, time and meal
/// type, and how it fits the user.
class RecipeListTile extends StatelessWidget {
  const RecipeListTile({
    super.key,
    required this.recipe,
    this.badge,
    required this.onTap,
  });

  final Recipe recipe;
  final FitBadge? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = recipe.listMeta;
    final badge = this.badge;
    return BbCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            child: SizedBox.square(
              dimension: AppConstants.recipeListThumbSize,
              child: RecipeImage(recipe: recipe),
            ),
          ),
          const SizedBox(width: AppConstants.spacing12),
          Expanded(
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
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: AppConstants.iconSizeXs,
                        color: AppTheme.mutedForeground,
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      Flexible(
                        child: Text(
                          meta,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeCaption,
                            color: AppTheme.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (badge != null) ...[
                  AppConstants.gap6,
                  FitBadgeView(badge, small: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
