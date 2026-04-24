import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_recipe.dart';
import '../../../widgets/common/signed_path_image.dart';

class RecipeListTile extends StatelessWidget {
  const RecipeListTile({super.key, required this.recipe, required this.onTap});

  final UserRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = recipe.ingredients.take(3).join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppConstants.paddingMd,
        child: Row(
          children: [
            _Thumbnail(imageUrl: recipe.imageUrl),
            AppConstants.gap16,
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = AppConstants.iconBadgeXl;
    final radius = BorderRadius.circular(AppConstants.radiusMd);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppTheme.muted, borderRadius: radius),
      child: const Icon(
        Icons.restaurant_menu_outlined,
        color: AppTheme.mutedForeground,
      ),
    );
    if (imageUrl == null) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: SignedPathImage(
        pathOrUrl: imageUrl,
        width: size,
        height: size,
        placeholder: fallback,
        errorWidget: fallback,
      ),
    );
  }
}
