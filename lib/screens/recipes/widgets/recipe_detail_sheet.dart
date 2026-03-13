import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/recipe.dart';

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            recipe.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          if (recipe.description != null) ...[
            const SizedBox(height: 8),
            Text(
              recipe.description!,
              style: const TextStyle(color: AppTheme.mutedForeground),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (recipe.cookTime != null)
                _infoChip(Icons.access_time, '${recipe.cookTime} Min.'),
              if (recipe.servings != null)
                _infoChip(Icons.people, '${recipe.servings} Port.'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Zutaten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...recipe.ingredients.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $i', style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Zubereitung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...recipe.instructions.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedForeground),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.foreground)),
        ],
      ),
    );
  }
}
