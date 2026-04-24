import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/user_recipe.dart';
import '../../../../providers/user_recipes_provider.dart';
import '../../../recipes/widgets/recipe_list_tile.dart';

/// Opens a modal bottom sheet that lets the user pick one of their saved
/// recipes. Returns the selected [UserRecipe], or `null` if dismissed.
Future<UserRecipe?> showRecipeSelectorSheet(BuildContext context) {
  return showModalBottomSheet<UserRecipe>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: SafeArea(top: false, child: _RecipeSelectorBody()),
    ),
  );
}

class _RecipeSelectorBody extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RecipeSelectorBody> createState() =>
      _RecipeSelectorBodyState();
}

class _RecipeSelectorBodyState extends ConsumerState<_RecipeSelectorBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userRecipesProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userRecipesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingMd,
            AppConstants.spacingLg,
            AppConstants.spacingMd,
          ),
          child: Text(
            'Rezept auswählen',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        const Divider(height: 1, thickness: AppConstants.dividerThickness),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const Center(
              child: Text(
                'Konnte Rezepte nicht laden',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return const Center(
                  child: Text(
                    'Noch keine Rezepte',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: recipes.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: AppConstants.dividerThickness,
                ),
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return RecipeListTile(
                    recipe: recipe,
                    onTap: () => Navigator.of(context).pop(recipe),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
