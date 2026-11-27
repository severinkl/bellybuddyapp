import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/meal_entry.dart';
import '../../../../providers/ingredient_suggestion_provider.dart';
import '../../../../router/route_names.dart';
import '../../../../widgets/common/flagged_ingredients_line.dart';
import '../meal_image.dart';

/// A diary meal: its photo and „Zutaten", and under them, whenever the meal
/// has suggestion groups, the line naming its flagged ingredients.
class MealDetail extends ConsumerWidget {
  final MealEntry meal;

  const MealDetail({super.key, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = ref.watch(mealSuggestionGroupsProvider(meal.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meal.imageUrl != null)
          MealImage(
            imageUrl: meal.imageUrl!,
            semanticLabel: meal.title.trim().isEmpty
                ? 'Foto'
                : 'Foto: ${meal.title.trim()}',
          ),
        if (meal.ingredients.isNotEmpty)
          Container(
            width: double.infinity,
            padding: AppConstants.paddingMd,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zutaten',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeSubtitle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppConstants.gap8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: meal.ingredients
                      .map((i) => Chip(label: Text(i)))
                      .toList(),
                ),
                if (flagged.isNotEmpty) ...[
                  AppConstants.gap8,
                  FlaggedIngredientsLine(
                    names: [for (final g in flagged) g.ingredientName],
                    onOpen: () =>
                        context.push(RoutePaths.ingredientSuggestions),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
