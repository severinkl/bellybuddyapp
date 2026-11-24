import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/my_recipe_item.dart';
import '../../../models/user_recipe.dart';
import '../../../services/recipes/recipe_fit.dart';
import '../../../widgets/common/bb_card.dart';
import '../../recipes/widgets/add_recipe_chooser_sheet.dart';
import '../../recipes/widgets/recipe_card.dart';
import '../../recipes/widgets/recipe_collection_card.dart';
import 'discover_section.dart';

/// Entdecken's „Rezepte": „Für dich" (the collection's top picks) and
/// „Meine Rezepte" (up to [shown] own and saved recipes, „+" and „Alle ›").
/// The two parts load and fail on their own.
class DiscoverRecipesSection extends StatelessWidget {
  const DiscoverRecipesSection({
    super.key,
    required this.forYou,
    required this.mine,
    required this.onOpenAll,
    required this.onOpenMine,
    required this.onOpenRecipe,
    required this.onOpenOwn,
  });

  /// The section, with its „Alle ›" to the collection.
  static const sectionKey = Key('discover_recipes');

  /// „Für dich".
  static const forYouKey = Key('discover_recipes_for_you');

  /// „Meine Rezepte", with its „+" and „Alle ›".
  static const mineKey = Key('discover_recipes_mine');

  /// How many recipes „Meine Rezepte" shows.
  static const shown = 6;

  final AsyncValue<List<RecipeFit>> forYou;
  final AsyncValue<List<MyRecipeItem>> mine;

  /// The header's „Alle ›": the whole collection.
  final VoidCallback onOpenAll;

  /// „Meine Rezepte"'s „Alle ›".
  final VoidCallback onOpenMine;

  /// A collection recipe, by id.
  final ValueChanged<String> onOpenRecipe;
  final ValueChanged<UserRecipe> onOpenOwn;

  @override
  Widget build(BuildContext context) {
    return DiscoverSection(
      key: sectionKey,
      title: 'Rezepte',
      actions: [DiscoverAllLink(onTap: onOpenAll)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_forYou(), AppConstants.gap16, _mine(context)],
      ),
    );
  }

  Widget _forYou() {
    final fits = forYou.value;
    return Column(
      key: forYouKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SubHeader(
          title: 'Für dich',
          caption: 'passend zu deinen Angaben',
        ),
        AppConstants.gap8,
        switch (fits) {
          null => DiscoverNote.pending(forYou, 'Rezepte'),
          [] => const DiscoverNote('Noch keine Rezepte.'),
          final fits => _CardRow([
            for (final fit in fits)
              RecipeCollectionCard(
                recipe: fit.recipe,
                badge: fit.badge,
                onTap: () => onOpenRecipe(fit.recipe.id),
              ),
          ]),
        },
      ],
    );
  }

  Widget _mine(BuildContext context) {
    final items = mine.value;
    final hasAny = items != null && items.isNotEmpty;
    return Column(
      key: mineKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubHeader(
          title: 'Meine Rezepte',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Rezept hinzufügen',
              onPressed: () => showAddRecipeChooserSheet(context),
            ),
            if (hasAny)
              DiscoverAllLink(
                onTap: onOpenMine,
                semanticsLabel: 'Alle meine Rezepte',
              ),
          ],
        ),
        AppConstants.gap8,
        switch (items) {
          null => DiscoverNote.pending(mine, 'Rezepte'),
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
          final items => _CardRow([
            for (final item in items.take(shown))
              switch (item) {
                OwnRecipe(:final recipe) => RecipeCard(
                  recipe: recipe,
                  onTap: () => onOpenOwn(recipe),
                ),
                SavedRecipe(:final recipe) => RecipeCollectionCard(
                  recipe: recipe,
                  tag: RecipeCardTag.saved,
                  onTap: () => onOpenRecipe(recipe.id),
                ),
              },
          ]),
        },
      ],
    );
  }
}

/// A sub-section's title with an optional caption beneath, and [actions].
class _SubHeader extends StatelessWidget {
  const _SubHeader({
    required this.title,
    this.caption,
    this.actions = const [],
  });

  final String title;
  final String? caption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeSubtitle,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
              if (caption != null)
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    color: AppTheme.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// [cards] side by side at the Entdecken card width, scrolling sideways.
class _CardRow extends StatelessWidget {
  const _CardRow(this.cards);

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, card) in cards.indexed) ...[
              if (i > 0) const SizedBox(width: AppConstants.spacingSm),
              SizedBox(
                width: AppConstants.discoverRecipeCardWidth,
                child: card,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
