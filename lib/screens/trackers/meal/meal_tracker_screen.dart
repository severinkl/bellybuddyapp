import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/meal_entry.dart';
import '../../../models/user_recipe.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/ingredient_autocomplete_provider.dart';
import '../../../providers/meal_tracker_provider.dart';
import '../../../providers/user_recipes_provider.dart';
import '../../../router/navigation_extensions.dart';
import '../../../router/route_names.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/logger.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/editable_app_bar_title.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import '../../../widgets/common/ingredient_search.dart';
import 'widgets/meal_image_section.dart';
import 'widgets/meal_title_sheet.dart';
import 'widgets/recipe_selector_sheet.dart';

const _log = AppLogger('MealTrackerScreen');

class MealTrackerScreen extends ConsumerStatefulWidget {
  const MealTrackerScreen({
    super.key,
    this.mealId,
    this.initial,
    this.initialDate,
    this.initialRecipe,
  });

  /// When non-null, the screen renders in edit mode for the meal with this ID.
  final String? mealId;

  /// Directly-provided meal for edit mode. Preferred over looking up via
  /// [mealId]: the detail-sheet navigation passes the already-loaded
  /// `MealEntry` as GoRouter `extra`, avoiding a provider lookup that would
  /// miss because the diary uses `diaryEntriesProvider`, not `entriesProvider`.
  final MealEntry? initial;

  /// When non-null and in create mode, pre-fills the tracked-at date to this
  /// day at the current wall-clock time. Passed by the bottom-nav `+` button
  /// when the user triggers the tracker from the diary tab. Ignored in edit
  /// mode (the meal's stored trackedAt wins).
  final DateTime? initialDate;

  /// When non-null and in create mode, pre-fills the tracker with this
  /// recipe's title, ingredients, and imageUrl. Passed by RecipeDetailScreen
  /// via GoRouter extra. Ignored in edit mode.
  final UserRecipe? initialRecipe;

  static const drinkTrackerButtonKey = Key('drink_tracker_button');
  static const mealTrackerTitleKey = Key('meal_tracker_title');
  static const mealEditSaveKey = Key('meal_tracker_save_button');

  @override
  ConsumerState<MealTrackerScreen> createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends ConsumerState<MealTrackerScreen> {
  bool _mealNotFound = false;
  bool _savedAsRecipe = false;
  bool _savingAsRecipe = false;

  @override
  void initState() {
    super.initState();
    assert(
      widget.initial == null ||
          widget.mealId == null ||
          widget.initial!.id == widget.mealId,
      'initial.id must match mealId when both are provided',
    );
    // Deferred to a post-frame callback: Riverpod explicitly rejects provider
    // state changes during widget life-cycles (initState / build / dispose /
    // didChangeDependencies). The cost is a 1-frame flash of the default
    // ("Neue Mahlzeit" + empty ingredients) before the seeded data paints.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userRecipesProvider.notifier).fetch();
      final notifier = ref.read(mealTrackerProvider.notifier);
      if (widget.mealId == null) {
        notifier.reset();
        if (widget.initialDate != null) {
          notifier.setTrackedAt(buildTrackedAt(widget.initialDate));
        }
        if (widget.initialRecipe != null) {
          notifier.prefillFromRecipe(widget.initialRecipe!);
        }
        return;
      }
      // Prefer the meal handed to us via GoRouter `extra`; fall back to the
      // entriesProvider lookup for deep-link cold-starts where extra is absent.
      final meal = widget.initial ?? _lookupMeal(widget.mealId!);
      if (meal == null) {
        notifier.reset();
        setState(() => _mealNotFound = true);
        return;
      }
      notifier.seed(meal);
    });
  }

  /// Looks up a meal by id in the currently loaded [entriesProvider] state.
  /// Returns `null` if no matching meal is present.
  MealEntry? _lookupMeal(String id) {
    final entries = ref.read(entriesProvider);
    return entries.meals.where((m) => m.id == id).firstOrNull;
  }

  Future<void> _save() async {
    await flushFocusBeforeSave();
    if (!mounted) return;
    final notifier = ref.read(mealTrackerProvider.notifier);
    final state = ref.read(mealTrackerProvider);

    // Edit mode with no changes → silent pop. Avoids a pointless network
    // round-trip and keeps the UX honest.
    if (widget.mealId != null && !state.isDirty) {
      if (mounted) context.popOrGoDashboard();
      return;
    }

    // If the user never named the meal, interrupt save with a prompt so the
    // entry is identifiable in the diary. Dismissing the sheet cancels save
    // entirely; "Ohne Namen speichern" proceeds with the default title.
    if (state.title.trim() == kDefaultMealTitle) {
      final outcome = await showMealTitleSheet(context);
      if (!mounted) return;
      switch (outcome) {
        case null:
          return; // dismissed — abort save
        case MealTitleEntered(title: final t):
          notifier.setTitle(t);
        case MealTitleSkipped():
          // fall through with the default title already in state
          break;
      }
    }

    final ok = await saveWithFeedback(context, () => notifier.save());

    // Edit mode: pop only on success — saveWithFeedback already surfaced the
    // error SnackBar on failure, and keeping the screen lets the user retry.
    // Create mode stays on the success overlay regardless (failure leaves the
    // user on the form, same behavior as before).
    if (!mounted) return;
    if (widget.mealId != null && ok) context.popOrGoDashboard();
  }

  bool _canSave(MealTrackerState state) {
    if (state.isAnalyzing || state.isSaving) return false;
    if (state.ingredients.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_mealNotFound) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.popOrGoDashboard(),
          ),
          title: const Text('Mahlzeit'),
        ),
        body: const Center(
          child: Text(
            'Mahlzeit nicht gefunden',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      );
    }

    final state = ref.watch(mealTrackerProvider);
    final canPop = widget.mealId == null || !state.isDirty;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await _confirmDiscard(context);
        if (confirmed == true && context.mounted) {
          context.popOrGoDashboard();
        }
      },
      child: TrackerScreenScaffold(
        titleWidget: EditableAppBarTitle(
          key: MealTrackerScreen.mealTrackerTitleKey,
          initialTitle: state.title == kDefaultMealTitle ? '' : state.title,
          placeholder: kDefaultMealTitle,
          onChanged: (v) {
            final notifier = ref.read(mealTrackerProvider.notifier);
            notifier.setTitle(v.isEmpty ? kDefaultMealTitle : v);
          },
        ),
        showSuccess: state.showSuccess,
        successMessage: 'Mahlzeit gespeichert!',
        successMascotAsset: AppConstants.mascotCool,
        successActions: [
          GestureDetector(
            onTap: () => context.push(RoutePaths.drinkTracker),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  size: AppConstants.iconSizeSm,
                  color: AppTheme.info,
                ),
                SizedBox(width: AppConstants.spacingSm),
                Text(
                  'Getränk hinzufügen',
                  style: TextStyle(color: AppTheme.info),
                ),
              ],
            ),
          ),
        ],
        successBottomCallout: state.showSuccess
            ? _buildSaveAsRecipeBottom(state)
            : null,
        onSuccessDismissed: widget.initialRecipe != null
            ? () => context.go(RoutePaths.dashboard)
            : null,
        body: _buildBody(state),
      ),
    );
  }

  /// Watches userRecipesProvider so the UI rebuilds if the recipe list
  /// arrives after first paint, then delegates to [hasMatchingUserRecipe].
  bool _hasMatchingRecipe(String title) =>
      hasMatchingUserRecipe(title, ref.watch(userRecipesProvider).value);

  Widget _buildSaveAsRecipeBottom(MealTrackerState state) {
    final saved = _savedAsRecipe || _hasMatchingRecipe(state.title);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!saved) ...[
            const Text(
              'Speicher diese Mahlzeit als Rezept, um sie später schneller wieder einzutragen.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: AppTheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            AppConstants.gap8,
          ],
          BbButton(
            label: saved ? 'Als Rezept gespeichert' : 'Als Rezept speichern',
            icon: saved ? Icons.check : Icons.bookmark_add_outlined,
            isLoading: _savingAsRecipe,
            onPressed: saved ? null : () => _saveAsRecipe(state),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsRecipe(MealTrackerState state) async {
    if (_savedAsRecipe || _savingAsRecipe) return;
    setState(() => _savingAsRecipe = true);
    try {
      await ref
          .read(userRecipesProvider.notifier)
          .create(
            title: state.title,
            ingredients: state.ingredients,
            imageUrl: state.savedImageUrl,
          );
      if (!mounted) return;
      setState(() {
        _savedAsRecipe = true;
        _savingAsRecipe = false;
      });
    } catch (e, st) {
      _log.error('save as recipe failed', e, st);
      if (!mounted) return;
      setState(() => _savingAsRecipe = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fehler beim Speichern')));
    }
  }

  Future<bool?> _confirmDiscard(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        content: const Text('Deine Änderungen gehen verloren.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Weiter bearbeiten'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MealTrackerState state) {
    final notifier = ref.read(mealTrackerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateTimeChips(
            value: state.trackedAt,
            onChanged: notifier.setTrackedAt,
          ),
          AppConstants.gap16,
          Consumer(
            builder: (_, ref, _) {
              // Scoped Consumer so userRecipesProvider's load → data
              // transition only rebuilds the image section, not the whole
              // screen. Previously the AppBar button had the same isolation
              // via its own Consumer.
              final hasRecipes =
                  ref.watch(userRecipesProvider).value?.isNotEmpty ?? false;
              return MealImageSection(
                imageBytes: state.imageBytes,
                isAnalyzing: state.isAnalyzing,
                onImagePicked: (bytes, name) async {
                  notifier.setImage(bytes, name);
                  try {
                    await notifier.analyzeImage(bytes, name);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fehler bei der Analyse.'),
                        ),
                      );
                    }
                  }
                },
                onClearImage: () {
                  notifier.clearImage();
                  notifier.setTitle(kDefaultMealTitle);
                },
                onPickRecipe: hasRecipes ? _openRecipeSelector : null,
              );
            },
          ),
          AppConstants.gap16,
          Consumer(
            builder: (context, ref, _) {
              final ingredients = ref.watch(mealTrackerProvider).ingredients;
              final autocomplete = ref.watch(ingredientAutocompleteProvider);
              final autocompleteNotifier = ref.read(
                ingredientAutocompleteProvider.notifier,
              );
              final trackerNotifier = ref.read(mealTrackerProvider.notifier);
              return IngredientSearch(
                ingredients: ingredients,
                suggestions: autocomplete.suggestions,
                onSearch: autocompleteNotifier.searchIngredients,
                onAdd: trackerNotifier.addIngredient,
                onRemove: trackerNotifier.removeIngredient,
                onDeleteIngredient: autocompleteNotifier.deleteUserIngredient,
              );
            },
          ),
          AppConstants.gap16,
          // "Getränk tracken" button
          OutlinedButton.icon(
            key: MealTrackerScreen.drinkTrackerButtonKey,
            onPressed: () => context.push(RoutePaths.drinkTracker),
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('Getränk tracken'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.info,
              side: const BorderSide(color: AppTheme.info),
            ),
          ),
          AppConstants.gap8,
          // Save button
          BbButton(
            key: MealTrackerScreen.mealEditSaveKey,
            label: 'Speichern',
            isLoading: state.isSaving,
            onPressed: _canSave(state) ? _save : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openRecipeSelector() async {
    final recipe = await showRecipeSelectorSheet(context);
    if (recipe == null || !mounted) return;
    ref.read(mealTrackerProvider.notifier).prefillFromRecipe(recipe);
  }
}

/// True iff [recipes] contains a recipe whose title matches [title] after
/// trimming + lowercasing. Returns false for empty/whitespace titles or
/// when [recipes] is still loading (null). Pure helper for unit testing —
/// the screen's `_hasMatchingRecipe` watches the provider then delegates here.
bool hasMatchingUserRecipe(String title, List<UserRecipe>? recipes) {
  final normalized = title.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (recipes == null) return false;
  return recipes.any((r) => r.title.trim().toLowerCase() == normalized);
}
