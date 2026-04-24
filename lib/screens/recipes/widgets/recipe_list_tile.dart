import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_recipe.dart';

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
    const size = 56.0;
    final radius = BorderRadius.circular(AppConstants.radiusMd);
    if (imageUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppTheme.muted, borderRadius: radius),
        child: const Icon(
          Icons.restaurant_menu_outlined,
          color: AppTheme.mutedForeground,
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
