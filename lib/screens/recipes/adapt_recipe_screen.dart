import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/adapted_recipe.dart';
import '../../models/meal_prefill.dart';
import '../../models/recipe.dart';
import '../../models/user_recipe.dart';
import '../../providers/adapt_recipe_provider.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/recipes/recipe_copy.dart';
import '../../services/recipes/recipe_fit.dart';
import '../../utils/german_list.dart';
import '../../utils/logger.dart';
import '../../utils/url_utils.dart';
import '../../widgets/buddy/buddy.dart';
import '../../widgets/buddy/buddy_side_header.dart';
import '../../widgets/common/bb_button.dart';
import 'collection_recipe_screen.dart';
import 'widgets/fit_badge_view.dart';
import 'widgets/ingredient_line_view.dart';
import 'widgets/recipe_collection_card.dart';
import 'widgets/recipe_image.dart';
import 'widgets/recipe_page_parts.dart';
import 'widgets/recipe_steps.dart';

/// „Für mich anpassen" for the collection recipe [recipeId]
/// (`/collection/:id/adapt`): the Buddy rebuilds it for the user, with the
/// swaps and the changed steps marked, to save in „Meine Rezepte" or log as
/// a meal.
///
/// The AI call starts at once only when [requested] (pushed by the
/// detail's button); opened any other way, the screen asks first. The
/// answer lives as long as the screen.
class AdaptRecipeScreen extends ConsumerStatefulWidget {
  const AdaptRecipeScreen({
    super.key,
    required this.recipeId,
    this.requested = false,
    this.openUrl = launchUrl,
  });

  static const saveKey = Key('adapt_save'),
      logKey = Key('adapt_log'),
      retryKey = Key('adapt_retry'),
      startKey = Key('adapt_start');

  static const loading = 'Ich bau’s für dich um …';
  static const loadingSub =
      'Ich tausche, was für dich kritisch ist, und prüfe jede Zutat im '
      'FODMAP-Katalog.';
  static const allChecked = 'Alle Zutaten mit dem FODMAP-Katalog geprüft';

  /// The check line while [names] are not in the catalog.
  static String someUnknown(List<String> names) =>
      'Mit dem FODMAP-Katalog geprüft. Nicht im Katalog: ${joinGerman(names)}';

  /// What the Buddy says when no adaptation came back. Never „passt": a
  /// recipe without anything to swap may still rest on unknowns.
  static String messageFor(AdaptFailure f) => switch (f) {
    AdaptFailure.later =>
      'Ich bin gerade ausgelastet. Versuch es bitte später nochmal.',
    AdaptFailure.failed =>
      'Das hat gerade nicht geklappt. Versuch es bitte nochmal.',
    AdaptFailure.nothingToAdapt => 'Hier muss ich für dich nichts tauschen.',
    AdaptFailure.cannotJudge =>
      'Ob ich hier etwas tauschen muss, kann ich nicht prüfen: Mir fehlen '
          'Angaben zu den Zutaten.',
  };

  static const saveFailed =
      'Speichern hat nicht geklappt. Bitte versuch es nochmal.';

  final String recipeId;

  /// Whether the user asked for it (the detail's „Für mich anpassen").
  final bool requested;

  /// Opens the original's source (`launchUrl`; tests record the launches).
  final UrlOpener openUrl;

  @override
  ConsumerState<AdaptRecipeScreen> createState() => _AdaptRecipeScreenState();
}

class _AdaptRecipeScreenState extends ConsumerState<AdaptRecipeScreen> {
  static const _log = AppLogger('AdaptRecipeScreen');

  /// The own recipe the answer was saved as.
  UserRecipe? _saved;
  bool _saving = false;

  AdaptRecipeNotifier get _adapt =>
      ref.read(adaptRecipeProvider(widget.recipeId).notifier);

  @override
  void initState() {
    super.initState();
    if (widget.requested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_adapt.start());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adaptRecipeProvider(widget.recipeId));
    AdaptedRecipe? result;
    final Widget body;
    if (state.isLoading ||
        (widget.requested && state is AsyncData && state.value == null)) {
      // Requested: working from the first frame, before start() runs.
      body = const _Working();
    } else if (state case AsyncError(:final error)) {
      body = _Failure(
        failure: error is AdaptRecipeException
            ? error.failure
            : AdaptFailure.failed,
        onRetry: () => unawaited(_adapt.retry()),
        onBack: _backToRecipe,
      );
    } else if (state.value case final adapted?) {
      result = adapted;
      body = _Result(
        adapted: adapted,
        fit: ref.watch(recipeFitProvider(widget.recipeId)).value,
        openUrl: widget.openUrl,
      );
    } else {
      body = _Question(onStart: () => unawaited(_adapt.start()));
    }
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
          onPressed: context.popOrGoDashboard,
        ),
        // Nothing is „angepasst" before the answer is there.
        title: Text(
          result == null ? 'Für mich anpassen' : RecipeCopy.adaptedForYou,
        ),
      ),
      body: body,
      bottomNavigationBar: result == null ? null : _actions(result),
    );
  }

  /// „In Meine Rezepte speichern" (then „gespeichert", opening it) and
  /// „Als Essen eintragen".
  Widget _actions(AdaptedRecipe adapted) {
    final saved = _saved;
    return SafeArea(
      top: false,
      child: Padding(
        padding: AppConstants.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BbButton(
              key: AdaptRecipeScreen.saveKey,
              label: saved == null
                  ? 'In Meine Rezepte speichern'
                  : 'In Meine Rezepte gespeichert',
              icon: saved == null ? null : Icons.check,
              isSecondary: saved != null,
              isLoading: _saving,
              onPressed: saved == null
                  ? () => unawaited(_save(adapted))
                  : () => context.push(RoutePaths.recipeDetailFor(saved.id)),
            ),
            AppConstants.gap8,
            BbButton(
              key: AdaptRecipeScreen.logKey,
              label: 'Als Essen eintragen',
              isOutlined: true,
              onPressed: () => context.push(
                RoutePaths.mealTracker,
                extra: MealPrefill.ofAdapted(adapted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves [adapted] as an own recipe once; a failure says so.
  Future<void> _save(AdaptedRecipe adapted) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    UserRecipe? saved;
    try {
      saved = await ref
          .read(userRecipesProvider.notifier)
          .createAdapted(adapted);
    } catch (e, st) {
      _log.error('saving the adapted recipe failed', e, st);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = saved;
    });
    if (saved == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AdaptRecipeScreen.saveFailed)),
        );
    }
  }

  /// Back to the recipe's detail: popped, or opened when nothing is below.
  void _backToRecipe() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.collectionRecipeFor(widget.recipeId));
    }
  }
}

/// The Buddy with [line] in his bubble: above him on a stage, or beside
/// him ([beside]), where the bubble shows the whole line however long.
class _TalkingBuddy extends StatefulWidget {
  const _TalkingBuddy({
    required this.mood,
    required this.line,
    this.beside = false,
    this.fontSize = AppTheme.fontSizeSubtitleLG,
  });

  static const _besideSize = Size(
    AppConstants.adaptBuddyBesideHeight * kBuddyStageAspect,
    AppConstants.adaptBuddyBesideHeight,
  );

  final BuddyMood mood;
  final String line;
  final bool beside;

  /// The size of the bubble's text beside him.
  final double fontSize;

  @override
  State<_TalkingBuddy> createState() => _TalkingBuddyState();
}

class _TalkingBuddyState extends State<_TalkingBuddy> {
  late final BuddyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BuddyController(mood: widget.mood)
      ..say(widget.line, duration: null);
  }

  @override
  void didUpdateWidget(_TalkingBuddy old) {
    super.didUpdateWidget(old);
    _controller.mood = widget.mood;
    if (old.line != widget.line) _controller.say(widget.line, duration: null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beside) {
      return BuddySideHeader(
        controller: _controller,
        buddySize: _TalkingBuddy._besideSize,
        grow: true,
        fontSize: widget.fontSize,
      );
    }
    return SizedBox(
      height: AppConstants.adaptBuddyStageHeight,
      child: BuddyStage(controller: _controller),
    );
  }
}

/// [children] centred, scrolling when they don't fit.
class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Opened without the user asking: the Buddy offers, nothing is sent yet.
class _Question extends StatelessWidget {
  const _Question({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _Centered(
      children: [
        const _TalkingBuddy(
          mood: BuddyMood.happy,
          line: 'Soll ich das Rezept für dich umbauen?',
        ),
        AppConstants.gap24,
        BbButton(
          key: AdaptRecipeScreen.startKey,
          label: 'Für mich anpassen',
          onPressed: onStart,
        ),
      ],
    );
  }
}

/// The Buddy at work, calm.
class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      children: [
        _TalkingBuddy(mood: BuddyMood.zen, line: AdaptRecipeScreen.loading),
        AppConstants.gap16,
        Text(
          AdaptRecipeScreen.loadingSub,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// No adaptation: the Buddy says why, with „Nochmal versuchen" when trying
/// again may help, else „Zurück zum Rezept".
class _Failure extends StatelessWidget {
  const _Failure({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final AdaptFailure failure;
  final VoidCallback onRetry, onBack;

  @override
  Widget build(BuildContext context) {
    final retryable = switch (failure) {
      AdaptFailure.later || AdaptFailure.failed => true,
      AdaptFailure.nothingToAdapt || AdaptFailure.cannotJudge => false,
    };
    return SingleChildScrollView(
      padding: AppConstants.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TalkingBuddy(
            mood: BuddyMood.empathetic,
            line: AdaptRecipeScreen.messageFor(failure),
            beside: true,
          ),
          AppConstants.gap24,
          if (retryable)
            BbButton(
              key: AdaptRecipeScreen.retryKey,
              label: 'Nochmal versuchen',
              onPressed: onRetry,
            )
          else
            BbButton(label: 'Zurück zum Rezept', onPressed: onBack),
        ],
      ),
    );
  }
}

/// The adapted recipe: the original's picture with the pill, the new title,
/// the Buddy's note, the check line, the ingredients with the swaps and
/// removals marked, the steps with the changed ones highlighted, and the
/// original with its source.
class _Result extends StatelessWidget {
  const _Result({
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
            _TalkingBuddy(
              mood: BuddyMood.happy,
              line: adapted.note,
              beside: true,
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
                all
                    ? AdaptRecipeScreen.allChecked
                    : AdaptRecipeScreen.someUnknown(unknown),
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

/// „Zutaten": each adapted ingredient (✓, or „?" and „unbekannt" when not
/// in the catalog; a swap with its original struck), then the removed
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
            note: i.unknown ? 'unbekannt' : null,
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
              failureMessage: CollectionRecipeScreen.sourceFailed,
              open: openUrl,
              mode: LaunchMode.inAppBrowserView,
            ),
    );
  }
}
