import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/adapted_recipe.dart';
import '../../models/meal_prefill.dart';
import '../../models/user_recipe.dart';
import '../../providers/adapt_recipe_provider.dart';
import '../../providers/recipe_collection_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../services/recipes/recipe_copy.dart';
import '../../services/user_recipe_service.dart';
import '../../utils/logger.dart';
import '../../utils/url_utils.dart';
import '../../widgets/buddy/buddy_pose.dart';
import '../../widgets/buddy/buddy_says.dart';
import '../../widgets/common/bb_button.dart';
import 'widgets/adapted_recipe_view.dart';

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
    // From the first frame, so the original (picture, meta, servings) is
    // loaded by the time the answer comes, also on a deep link.
    final fit = ref.watch(recipeFitProvider(widget.recipeId)).value;
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
      body = AdaptedRecipeView(
        adapted: adapted,
        fit: fit,
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

  /// Saves [adapted] as an own recipe once; a failure says so, and so do
  /// steps the backend couldn't keep.
  Future<void> _save(AdaptedRecipe adapted) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    UserRecipe? saved;
    var tooLong = false;
    try {
      saved = await ref
          .read(userRecipesProvider.notifier)
          .createAdapted(adapted);
    } on RecipeTooLongException {
      _log.warn('the adapted recipe is too long to save');
      tooLong = true;
    } catch (e, st) {
      _log.error('saving the adapted recipe failed', e, st);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = saved;
    });
    final message = switch (saved) {
      // Trying again changes nothing: said so.
      null when tooLong => RecipeCopy.adaptTooLong,
      null => RecipeCopy.adaptSaveFailed,
      // A backend without core #11's columns kept the rest only.
      _ when saved.lostSteps([for (final step in adapted.steps) step.text]) =>
        RecipeCopy.stepsNotSaved,
      _ => null,
    };
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Back to the recipe's detail: popped, or opened when nothing is below.
  void _backToRecipe() =>
      context.popOr(RoutePaths.collectionRecipeFor(widget.recipeId));
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
        const BuddySays(
          line: RecipeCopy.adaptQuestion,
          height: AppConstants.adaptBuddyStageHeight,
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
        BuddySays(
          mood: BuddyMood.zen,
          line: RecipeCopy.adaptWorking,
          height: AppConstants.adaptBuddyStageHeight,
        ),
        AppConstants.gap16,
        Text(
          RecipeCopy.adaptWorkingSub,
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
    return SingleChildScrollView(
      padding: AppConstants.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BuddySays.beside(
            mood: BuddyMood.empathetic,
            line: RecipeCopy.adaptFailed(failure),
            height: AppConstants.adaptBuddyBesideHeight,
          ),
          AppConstants.gap24,
          if (failure.retryable)
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
