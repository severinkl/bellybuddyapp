import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/meal_prefill.dart';
import '../../models/recipe.dart';
import '../../providers/plus_provider.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/recipes/recipe_copy.dart';
import '../../services/recipes/recipe_fit.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/plus_badge.dart';
import 'widgets/ingredient_line_view.dart';
import 'widgets/recipe_image.dart';
import 'widgets/recipe_page_parts.dart';
import 'widgets/recipe_steps.dart';

/// A recipe of the collection (`/collection/:id`): how each ingredient fits
/// the user (✓ / ⚠), whether it is against their diet, „Für mich anpassen"
/// while one is kritisch or it is, the steps and the source, with „Als
/// Essen eintragen" and „Merken" below.
class CollectionRecipeScreen extends ConsumerWidget {
  const CollectionRecipeScreen({
    super.key,
    required this.recipeId,
    this.openUrl = launchUrl,
  });

  static const adaptKey = Key('recipe_adapt'),
      saveKey = Key('recipe_save'),
      logKey = Key('recipe_log'),
      sourceKey = Key('recipe_source');

  static const saved = 'Gemerkt. Du findest es unter „Meine Rezepte".';
  static const unsaved = 'Nicht mehr gemerkt.';

  final String recipeId;

  /// Opens the source (`launchUrl`; tests record the launches).
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeFitProvider(recipeId));
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
          onPressed: context.popOrGoDashboard,
        ),
        // The recipe's name is the page's heading below; said once.
        title: const Text('Rezept'),
      ),
      body: switch (state) {
        AsyncData(value: final fit?) => _RecipeBody(fit: fit, openUrl: openUrl),
        AsyncData() => const Center(
          child: Text(
            'Rezept nicht gefunden',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
        AsyncError() => BbErrorState(
          message: 'Konnte das Rezept nicht laden',
          onRetry: () =>
              unawaited(ref.read(recipeCollectionProvider.notifier).refresh()),
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: switch (state) {
        AsyncData(value: final fit?) => _ActionBar(recipe: fit.recipe),
        _ => null,
      },
    );
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody({required this.fit, required this.openUrl});

  final RecipeFit fit;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final recipe = fit.recipe;
    return SingleChildScrollView(
      padding: AppConstants.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecipePageHead(
            image: RecipeImage(recipe: recipe),
            title: recipe.title,
            meta: recipe.detailMeta,
            badge: fit.badge,
          ),
          if (fit.offDiet case final diet?) ...[
            AppConstants.gap8,
            Text(
              RecipeCopy.offDiet(diet),
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
              ),
            ),
          ],
          AppConstants.gap16,
          _IngredientsCard(fit: fit),
          if (recipe.instructions.isNotEmpty) ...[
            AppConstants.gap16,
            RecipeSectionCard(
              title: 'Zubereitung',
              children: [RecipeSteps(steps: recipe.instructions)],
            ),
          ],
          if (recipe.sourceLink != null && recipe.sourceLabel != null) ...[
            AppConstants.gap8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: RecipeSourceLink(
                key: CollectionRecipeScreen.sourceKey,
                recipe: recipe,
                openUrl: openUrl,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// „Zutaten": each line with its mark, and „Für mich anpassen" while one is
/// kritisch or the recipe is against the diet (core adapts it for both).
/// While Plus is locked the button keeps a „Plus" badge and opens the
/// paywall instead.
class _IngredientsCard extends ConsumerWidget {
  const _IngredientsCard({required this.fit});

  final RecipeFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plusLocked = ref.watch(plusAccessProvider) == PlusAccess.locked;
    final recipe = fit.recipe;
    final kritisch = {for (final l in fit.kritisch) l.line.name}.toList();
    return RecipeSectionCard(
      title: 'Zutaten',
      servings: recipe.servingsLabel,
      children: [
        ..._lines(),
        if (kritisch.isNotEmpty || fit.offDiet != null) ...[
          AppConstants.gap12,
          FilledButton.tonalIcon(
            key: CollectionRecipeScreen.adaptKey,
            // `extra: true`: the user asked, so the adapt screen may start
            // the AI call at once.
            onPressed: () => plusLocked
                ? context.push(RoutePaths.plus)
                : context.push(
                    RoutePaths.collectionRecipeAdaptFor(recipe.id),
                    extra: true,
                  ),
            icon: const Icon(Icons.auto_awesome),
            label: plusLocked
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('Für mich anpassen')),
                      SizedBox(width: AppConstants.spacingSm),
                      PlusBadge(),
                    ],
                  )
                : const Text('Für mich anpassen'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppConstants.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              textStyle: const TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AppConstants.gap8,
          Text(
            RecipeCopy.adaptHint(kritisch, diet: fit.offDiet),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaptionLG,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  /// The lines, marked once the fit is checked; an older recipe's text
  /// lines unmarked. The amounts' column only when a line has an amount.
  List<Widget> _lines() {
    final recipe = fit.recipe;
    if (recipe.isLegacy) {
      return [
        for (final text in recipe.legacyIngredients)
          IngredientLineView(name: text, amountColumn: false),
      ];
    }
    final amounts = recipe.ingredients.any((l) => l.amount != null);
    if (!fit.checked) {
      return [
        for (final line in recipe.ingredients)
          IngredientLineView(
            amount: line.amount,
            name: line.name,
            amountColumn: amounts,
          ),
      ];
    }
    return [
      for (final l in fit.lines)
        IngredientLineView(
          amount: l.line.amount,
          name: l.line.name,
          mark: l.mark,
          because: l.because,
          amountColumn: amounts,
        ),
    ];
  }
}

/// „Als Essen eintragen" and the „Merken" toggle.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  /// A tap of „Merken" is on its way (waiting for the saved recipes or the
  /// write): the button takes no second one meanwhile.
  bool _toggling = false;

  Recipe get recipe => widget.recipe;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(
      recipeFavoritesProvider.select((f) => f.isSaved(recipe.id)),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: AppConstants.paddingMd,
        child: Row(
          children: [
            Expanded(
              child: BbButton(
                key: CollectionRecipeScreen.logKey,
                label: 'Als Essen eintragen',
                onPressed: () => context.push(
                  RoutePaths.mealTracker,
                  extra: MealPrefill.ofRecipe(recipe),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            OutlinedButton.icon(
              key: CollectionRecipeScreen.saveKey,
              onPressed: _toggling ? null : () => unawaited(_toggle()),
              icon: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                color: saved ? AppTheme.buddyHeart : null,
              ),
              label: Text(saved ? 'Gemerkt' : 'Merken'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(0, AppConstants.buttonHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves the recipe or takes it back, at once, and says how it went.
  Future<void> _toggle() async {
    setState(() => _toggling = true);
    final messenger = ScaffoldMessenger.of(context);
    final favorites = ref.read(recipeFavoritesProvider.notifier);
    try {
      // A toggle needs the saved recipes: while they load, wait (a failure
      // then is the toggle's); after a failed load, load them again, also
      // when the error still carries the list from before it.
      switch (ref.read(recipeFavoritesProvider)) {
        case AsyncValue(isLoading: true):
          await ref
              .read(recipeFavoritesProvider.future)
              .then((_) {}, onError: (_) {});
        case AsyncValue(hasError: true):
          await favorites.refresh();
        case _:
      }
      final wasSaved = favorites.isSaved(recipe.id);
      final message = switch ((await favorites.toggle(recipe.id), wasSaved)) {
        // Another tap's write is still on its way; it says how it went.
        (null, _) => null,
        (false, _) => RecipeCopy.failed,
        (true, true) => CollectionRecipeScreen.unsaved,
        (true, false) => CollectionRecipeScreen.saved,
      };
      if (message != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }
}
