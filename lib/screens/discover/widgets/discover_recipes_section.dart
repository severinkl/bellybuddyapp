import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/user_recipe.dart';
import '../../../widgets/common/bb_card.dart';
import '../../recipes/widgets/add_recipe_chooser_sheet.dart';
import '../../recipes/widgets/recipe_card.dart';
import 'discover_section.dart';

/// Up to [shown] of the user's recipes in a row, „+" and „Alle ›"; none:
/// a line and „Erstes Rezept erstellen".
class DiscoverRecipesSection extends StatelessWidget {
  const DiscoverRecipesSection({
    super.key,
    required this.recipes,
    required this.onOpenAll,
    required this.onOpen,
  });

  /// The section, with its „+" and „Alle ›".
  static const sectionKey = Key('discover_recipes');

  /// How many recipes the row shows.
  static const shown = 6;

  final AsyncValue<List<UserRecipe>> recipes;
  final VoidCallback onOpenAll;
  final ValueChanged<UserRecipe> onOpen;

  @override
  Widget build(BuildContext context) {
    final list = recipes.value;
    final hasAny = list != null && list.isNotEmpty;
    return DiscoverSection(
      key: sectionKey,
      title: 'Meine Rezepte',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Rezept hinzufügen',
          onPressed: () => showAddRecipeChooserSheet(context),
        ),
        if (hasAny) DiscoverAllLink(onTap: onOpenAll),
      ],
      child: switch (list) {
        null => DiscoverNote.pending(recipes, 'Rezepte'),
        [] => BbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Noch keine Rezepte.',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
              AppConstants.gap12,
              FilledButton(
                onPressed: () => showAddRecipeChooserSheet(context),
                child: const Text('Erstes Rezept erstellen'),
              ),
            ],
          ),
        ),
        final items => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, recipe) in items.take(shown).indexed) ...[
                  if (i > 0) const SizedBox(width: AppConstants.spacingSm),
                  SizedBox(
                    width: AppConstants.discoverRecipeCardWidth,
                    child: RecipeCard(
                      recipe: recipe,
                      onTap: () => onOpen(recipe),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      },
    );
  }
}
