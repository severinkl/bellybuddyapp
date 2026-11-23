import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/meal_entry.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/user_recipes_provider.dart';
import '../../../repositories/entry_repository.dart';
import '../../../router/route_names.dart';
import '../../trackers/meal/meal_tracker_screen.dart'
    show hasMatchingUserRecipe;
import '../../../utils/logger.dart';
import '../../../widgets/common/bb_drag_handle.dart';
import '../../../widgets/common/bb_ingredient_chip.dart';
import '../../../widgets/common/bb_pastel_thumb.dart';
import '../../../widgets/common/bb_sheet_row.dart';

Future<void> showRecentMealPickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    // The sheet draws its own handle.
    showDragHandle: false,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (_) => const _RecentMealPickerSheet(),
  );
}

class _RecentMealPickerSheet extends ConsumerStatefulWidget {
  const _RecentMealPickerSheet();

  @override
  ConsumerState<_RecentMealPickerSheet> createState() =>
      _RecentMealPickerSheetState();
}

class _RecentMealPickerSheetState
    extends ConsumerState<_RecentMealPickerSheet> {
  static const _log = AppLogger('RecentMealPickerSheet');

  List<MealEntry>? _meals;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeals();
    // Usually loaded already (a no-op then): marks the meals saved as
    // recipes.
    Future.microtask(() => ref.read(userRecipesProvider.notifier).fetch());
  }

  Future<void> _fetchMeals() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final meals = await ref
          .read(entryRepositoryProvider)
          .fetchRecentMeals(userId: userId, limit: 20);
      if (mounted) {
        setState(() {
          _meals = meals;
          _loading = false;
        });
      }
    } catch (e, st) {
      _log.error('fetchRecentMeals failed', e, st);
      if (mounted) {
        setState(() {
          _meals = [];
          _loading = false;
        });
      }
    }
  }

  void _openEditorWith(MealEntry meal) {
    Navigator.of(context).pop();
    context.push(RoutePaths.recipeNew, extra: meal);
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(userRecipesProvider).value;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            const SizedBox(height: AppConstants.spacingSm),
            const BbDragHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingMd,
              ),
              child: Text(
                'Kürzliche Mahlzeiten',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _meals == null || _meals!.isEmpty
                  ? const Center(
                      child: Text(
                        'Keine kürzlichen Mahlzeiten',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                      ),
                      itemCount: _meals!.length,
                      separatorBuilder: (_, _) => AppConstants.gap8,
                      itemBuilder: (context, i) {
                        final meal = _meals![i];
                        final savedAsRecipe = hasMatchingUserRecipe(
                          meal.title,
                          recipes,
                        );
                        return BbSheetRow(
                          onTap: () => _openEditorWith(meal),
                          leading: BbPastelThumb(
                            title: meal.title,
                            imageUrl: meal.imageUrl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                meal.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeBody,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.foreground,
                                ),
                              ),
                              if (savedAsRecipe) ...[
                                AppConstants.gap4,
                                const _SavedAsRecipeLabel(),
                              ],
                              if (meal.ingredients.isNotEmpty) ...[
                                AppConstants.gap4,
                                Wrap(
                                  spacing: AppConstants.spacingXs,
                                  runSpacing: AppConstants.spacingXs,
                                  children: [
                                    for (final ingredient
                                        in meal.ingredients.take(3))
                                      BbIngredientChip(label: ingredient),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// „Schon als Rezept gespeichert" under a meal that is a recipe already.
class _SavedAsRecipeLabel extends StatelessWidget {
  const _SavedAsRecipeLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.bookmark_added_outlined,
          size: AppConstants.iconSizeXs,
          color: AppTheme.mutedForeground,
        ),
        SizedBox(width: AppConstants.spacingXs),
        Flexible(
          child: Text(
            'Schon als Rezept gespeichert',
            style: TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
