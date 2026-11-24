import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/meal_prefill.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/recipes/recipe_copy.dart';
import '../../services/recipes/recipe_fit.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import 'widgets/fit_badge_view.dart';
import 'widgets/ingredient_line_view.dart';
import 'widgets/recipe_image.dart';
import 'widgets/recipe_steps.dart';

/// A recipe of the collection (`/collection/:id`): how each ingredient fits
/// the user (✓ / ⚠), „Für mich anpassen" while one is kritisch, the steps
/// and the source, with „Als Essen eintragen" and „Merken" below.
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

  static const sourceFailed = 'Die Quelle konnte nicht geöffnet werden.';
  static const saved = 'Gemerkt. Du findest es unter „Meine Rezepte".';
  static const unsaved = 'Nicht mehr gemerkt.';
  static const saveFailed =
      'Das hat gerade nicht geklappt. Bitte versuch es nochmal.';

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
          onRetry: () => _retry(ref),
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: switch (state) {
        AsyncData(value: final fit?) => _ActionBar(recipe: fit.recipe),
        _ => null,
      },
    );
  }

  /// Loads the collection again, and the intolerance table with it (a
  /// failed load leaves the recipe unchecked).
  void _retry(WidgetRef ref) {
    unawaited(ref.read(recipeCollectionProvider.notifier).refresh());
    ref.invalidate(intoleranceRulesProvider);
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody({required this.fit, required this.openUrl});

  final RecipeFit fit;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final recipe = fit.recipe;
    final meta = recipe.detailMeta;
    final source = recipe.sourceUrl;
    final sourceName = _sourceNameOf(recipe);
    return SingleChildScrollView(
      padding: AppConstants.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: RecipeImage(recipe: recipe),
            ),
          ),
          AppConstants.gap16,
          Semantics(
            header: true,
            child: Text(
              recipe.title,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeDisplay,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
              ),
            ),
          ),
          if (meta.isNotEmpty) ...[AppConstants.gap8, _Meta(meta)],
          if (fit.badge case final badge?) ...[
            AppConstants.gap8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FitBadgeView(badge),
            ),
          ],
          AppConstants.gap16,
          _IngredientsCard(fit: fit),
          if (recipe.instructions.isNotEmpty) ...[
            AppConstants.gap16,
            _Card(
              title: 'Zubereitung',
              children: [RecipeSteps(steps: recipe.instructions)],
            ),
          ],
          if (source != null && sourceName != null) ...[
            AppConstants.gap8,
            _SourceLink(url: source, name: sourceName, openUrl: openUrl),
          ],
        ],
      ),
    );
  }

  /// The source's name, else its site; null without a link to open.
  static String? _sourceNameOf(Recipe recipe) {
    final url = recipe.sourceUrl;
    if (url == null) return null;
    final name = recipe.sourceName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final host = Uri.tryParse(url.trim())?.host ?? '';
    return host.isEmpty ? null : host;
  }
}

/// „35 Min · 2 Portionen" behind a clock.
class _Meta extends StatelessWidget {
  const _Meta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.schedule,
          size: AppConstants.iconSizeSm,
          color: AppTheme.mutedForeground,
        ),
        const SizedBox(width: AppConstants.spacing6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// A white card with a heading and, at its right, a muted [trailing].
class _Card extends StatelessWidget {
  const _Card({required this.title, this.trailing, required this.children});

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      color: Colors.white,
      showBorder: false,
      radius: AppConstants.radiusRound,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppConstants.spacingSm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              if (trailing case final trailing?)
                Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
            ],
          ),
          AppConstants.gap8,
          ...children,
        ],
      ),
    );
  }
}

/// „Zutaten": each line with its mark, and „Für mich anpassen" while one is
/// kritisch.
class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.fit});

  final RecipeFit fit;

  @override
  Widget build(BuildContext context) {
    final recipe = fit.recipe;
    final servings = recipe.servingsLabel;
    final kritisch = {for (final l in fit.kritisch) l.line.name}.toList();
    return _Card(
      title: 'Zutaten',
      trailing: servings == null ? null : 'für $servings',
      children: [
        ..._lines(),
        if (kritisch.isNotEmpty) ...[
          AppConstants.gap12,
          FilledButton.tonalIcon(
            key: CollectionRecipeScreen.adaptKey,
            // `extra: true`: the user asked, so the adapt screen may start
            // the AI call at once.
            onPressed: () => context.push(
              RoutePaths.collectionRecipeAdaptFor(recipe.id),
              extra: true,
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Für mich anpassen'),
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
            RecipeCopy.adaptHint(kritisch),
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
  /// lines unmarked.
  List<Widget> _lines() {
    final recipe = fit.recipe;
    if (recipe.isLegacy) {
      return [
        for (final text in recipe.legacyIngredients)
          IngredientLineView(name: text),
      ];
    }
    if (!fit.checked) {
      return [
        for (final line in recipe.ingredients)
          IngredientLineView(amount: line.amount, name: line.name),
      ];
    }
    return [
      for (final l in fit.lines)
        IngredientLineView(
          amount: l.line.amount,
          name: l.line.name,
          mark: l.mark,
          because: l.because,
        ),
    ];
  }
}

/// „Quelle: Name ›", opening the source in the in-app browser.
class _SourceLink extends StatelessWidget {
  const _SourceLink({
    required this.url,
    required this.name,
    required this.openUrl,
  });

  final String url, name;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        link: true,
        child: InkWell(
          key: CollectionRecipeScreen.sourceKey,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          onTap: () => openExternalUrl(
            context,
            url,
            failureMessage: CollectionRecipeScreen.sourceFailed,
            open: openUrl,
            mode: LaunchMode.inAppBrowserView,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingXs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.mutedForeground,
                    ),
                    children: [
                      const TextSpan(text: 'Quelle: '),
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          color: AppTheme.foreground,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.border,
                        ),
                      ),
                      const TextSpan(text: ' ›'),
                    ],
                  ),
                  semanticsLabel: 'Quelle: $name',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// „Als Essen eintragen" and the „Merken" toggle.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recipeFavoritesProvider);
    final saved = ref.read(recipeFavoritesProvider.notifier).isSaved(recipe.id);
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
              onPressed: () => _toggle(context, ref),
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
  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final favorites = ref.read(recipeFavoritesProvider.notifier);
    // After a failed load every toggle would fail: load them again first.
    if (ref.read(recipeFavoritesProvider) case AsyncError(hasValue: false)) {
      await favorites.refresh();
    }
    final wasSaved = favorites.isSaved(recipe.id);
    final ok = await favorites.toggle(recipe.id);
    final message = switch ((ok, wasSaved)) {
      (false, _) => CollectionRecipeScreen.saveFailed,
      (true, true) => CollectionRecipeScreen.unsaved,
      (true, false) => CollectionRecipeScreen.saved,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
