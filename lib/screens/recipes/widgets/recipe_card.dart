import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_recipe.dart';
import '../../../utils/title_color.dart';
import '../../../widgets/common/signed_path_image.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = recipe.ingredients.take(3).join(' · ');
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 1.1, child: _Image(recipe: recipe)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title.isEmpty ? 'Ohne Namen' : recipe.title,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    AppConstants.gap4,
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        color: AppTheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _Image extends StatelessWidget {
  const _Image({required this.recipe});
  final UserRecipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.imageUrl == null || recipe.imageUrl!.isEmpty) {
      return _PastelMonogram(title: recipe.title);
    }
    return SignedPathImage(
      pathOrUrl: recipe.imageUrl,
      placeholder: _PastelMonogram(title: recipe.title),
      errorWidget: _PastelMonogram(title: recipe.title),
    );
  }
}

class _PastelMonogram extends StatelessWidget {
  const _PastelMonogram({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.isEmpty ? '?' : title.characters.first.toUpperCase();
    return Container(
      color: pastelForTitle(title),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: AppTheme.fontSizeTitleLG,
          fontWeight: FontWeight.w300,
          color: AppTheme.foreground.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
