import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/adapted_recipe.dart';
import '../../../models/recipe.dart';
import '../../../services/recipes/recipe_copy.dart';
import '../../../services/recipes/recipe_fit.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/buddy/buddy_says.dart';
import 'fit_badge_view.dart';
import 'ingredient_line_view.dart';
import 'recipe_collection_card.dart';
import 'recipe_image.dart';
import 'recipe_page_parts.dart';
import 'recipe_steps.dart';

/// The adapted recipe: the original's picture with the pill, the new title,
/// the Buddy's note, the check line, the ingredients with the swaps and
/// removals marked, the steps with the changed ones highlighted, and the
/// original with its source.
class AdaptedRecipeView extends StatelessWidget {
  const AdaptedRecipeView({
    super.key,
    required this.adapted,
    required this.fit,
    required this.openUrl,
  });

  final AdaptedRecipe adapted;

  /// The original and how it fits the user; null while unknown (or gone
  /// from the collection).
  final RecipeFit? fit;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final fit = this.fit;
    final original = fit?.recipe;
    final meta = original?.detailMeta ?? '';
    final selfCheck = fit?.selfCheck ?? const [];
    final steps = adapted.steps;
    final changed = {
      for (final (i, step) in steps.indexed)
        if (step.changed) i,
    };
    return SingleChildScrollView(
      padding: AppConstants.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (original == null)
                    const RecipePlaceholder()
                  else
                    RecipeImage(recipe: original),
                  const Positioned(
                    top: AppConstants.spacing12,
                    left: AppConstants.spacing12,
                    child: RecipeTagPill(
                      RecipeCardTag.adapted,
                      label: RecipeCopy.adaptedForYou,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppConstants.gap16,
          Semantics(
            header: true,
            child: Text(
              adapted.title,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeDisplay,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
          ),
          if (meta.isNotEmpty) ...[AppConstants.gap8, RecipeMetaLine(meta)],
          // The catalog can't judge these (Histamin): said as on the detail.
          if (selfCheck.isNotEmpty) ...[
            AppConstants.gap8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FitBadgeView(SelfCheckBadge(selfCheck)),
            ),
          ],
          if (adapted.note.isNotEmpty) ...[
            AppConstants.gap16,
            BuddySays.beside(
              line: adapted.note,
              height: AppConstants.adaptBuddyBesideHeight,
              fontSize: AppTheme.fontSizeBodyLG,
            ),
          ],
          AppConstants.gap16,
          _CheckLine(adapted.unknownNames),
          AppConstants.gap16,
          _IngredientsCard(
            adapted: adapted,
            servings: original?.servingsLabel,
            // No ✓ while an intolerance can't be judged (or the fit is
            // unknown): it would read like a verdict on it.
            verdict: fit != null && fit.checked && selfCheck.isEmpty,
          ),
          if (steps.isNotEmpty) ...[
            AppConstants.gap16,
            RecipeSectionCard(
              title: 'Zubereitung',
              trailing: changed.isEmpty ? null : const _ChangedLegend(),
              children: [
                RecipeSteps(
                  steps: [for (final step in steps) step.text],
                  changed: changed,
                ),
              ],
            ),
          ],
          if (original != null) ...[
            AppConstants.gap8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _OriginalLine(original: original, openUrl: openUrl),
            ),
          ],
        ],
      ),
    );
  }
}

/// „Alle Zutaten mit dem FODMAP-Katalog geprüft" in green, or which
/// ingredients weren't in it on yellow: never „alle" with an unknown.
class _CheckLine extends StatelessWidget {
  const _CheckLine(this.unknown);

  final List<String> unknown;

  @override
  Widget build(BuildContext context) {
    final all = unknown.isEmpty;
    final color = all
        ? AppTheme.gutFeelingGoodIcon
        : AppTheme.gutFeelingNeutralIcon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: all
            ? AppTheme.gutFeelingGoodSoft
            : AppTheme.gutFeelingNeutralSoft,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing14,
          vertical: AppConstants.spacing10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              all ? Icons.task_alt : Icons.help_outline,
              size: AppConstants.iconSizeSm,
              color: color,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Text(
                all ? RecipeCopy.allChecked : RecipeCopy.someUnknown(unknown),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// „Zutaten": each adapted ingredient (✓, or „?" and „nicht im Katalog"
/// when not in it; a swap with its original struck), then the removed
/// ones struck with „weggelassen".
class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({
    required this.adapted,
    required this.servings,
    required this.verdict,
  });

  final AdaptedRecipe adapted;
  final String? servings;

  /// Whether a line in the catalog gets ✓ (else a neutral dot).
  final bool verdict;

  @override
  Widget build(BuildContext context) {
    final amounts = adapted.ingredients.any((i) => i.amount != null);
    final known = verdict ? LineMark.fits : LineMark.neutral;
    return RecipeSectionCard(
      title: 'Zutaten',
      trailing: servings == null
          ? null
          : Text('für $servings', style: RecipeSectionCard.captionStyle),
      children: [
        for (final i in adapted.ingredients)
          IngredientLineView(
            amount: i.amount,
            name: i.name,
            mark: i.unknown ? LineMark.unknown : known,
            replaces: i.replaces,
            // The line says „nicht im Katalog" itself, except for a swap.
            note: i.unknown && i.replaces != null
                ? RecipeCopy.notInCatalog
                : null,
            amountColumn: amounts,
          ),
        // A neutral dot keeps them in line with the marked names.
        for (final name in adapted.removed)
          IngredientLineView(
            name: name,
            mark: LineMark.neutral,
            removed: true,
            amountColumn: amounts,
          ),
      ],
    );
  }
}

/// The legend of the highlighted steps: a swatch and „geändert".
class _ChangedLegend extends StatelessWidget {
  const _ChangedLegend();

  @override
  Widget build(BuildContext context) {
    // Each changed step says „geändert" to screen readers itself.
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.recipeChanged,
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
            ),
            child: const SizedBox(
              width: AppConstants.recipeChangedSwatchWidth,
              height: AppConstants.recipeChangedSwatchHeight,
            ),
          ),
          const SizedBox(width: AppConstants.spacing6),
          const Text(
            RecipeCopy.stepChanged,
            style: RecipeSectionCard.captionStyle,
          ),
        ],
      ),
    );
  }
}

/// „Original: <title> · <source> ›", opening the source in the in-app
/// browser; plain text without a link.
class _OriginalLine extends StatelessWidget {
  const _OriginalLine({required this.original, required this.openUrl});

  final Recipe original;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final url = original.sourceUrl;
    return RecipeLinkLine(
      lead: 'Original: ',
      name: original.title,
      tail: switch (original.sourceLabel) {
        final source? => ' · $source',
        null => '',
      },
      onTap: url == null
          ? null
          : () => openExternalUrl(
              context,
              url,
              failureMessage: RecipeCopy.sourceFailed,
              open: openUrl,
              mode: LaunchMode.inAppBrowserView,
            ),
    );
  }
}
