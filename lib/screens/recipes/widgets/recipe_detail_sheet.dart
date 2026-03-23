import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/recipe.dart';
import '../../../config/constants.dart';

class RecipeDetailSheet extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailSheet({super.key, required this.recipe});

  static void show(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => RecipeDetailSheet(recipe: recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: AppConstants.dragHandleWidth,
              height: AppConstants.spacingXs,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(AppConstants.spacing2),
              ),
            ),
          ),
          AppConstants.gap16,
          Text(
            recipe.title,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (recipe.description != null) ...[
            AppConstants.gap8,
            Text(
              recipe.description!,
              style: const TextStyle(color: AppTheme.mutedForeground),
            ),
          ],
          AppConstants.gap16,
          Row(
            children: [
              if (recipe.cookTime != null)
                _infoChip(Icons.access_time, '${recipe.cookTime} Min.'),
              if (recipe.servings != null)
                _infoChip(Icons.people, '${recipe.servings} Port.'),
            ],
          ),
          AppConstants.gap24,
          const Text(
            'Zutaten',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppConstants.gap8,
          ...recipe.ingredients.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingXs),
              child: Text(
                '• $i',
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLG),
              ),
            ),
          ),
          AppConstants.gap24,
          const Text(
            'Zubereitung',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppConstants.gap8,
          ...recipe.instructions.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
              child: Text(
                '${e.key + 1}. ${e.value}',
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLG),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: AppConstants.spacing12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing12,
        vertical: AppConstants.spacing6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedForeground),
          const SizedBox(width: AppConstants.spacingXs),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaptionLG,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
