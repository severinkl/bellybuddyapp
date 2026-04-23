import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/meal_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/meal_tracker_provider.dart';
import '../../../router/navigation_extensions.dart';
import '../../../router/route_names.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import 'widgets/ingredient_search.dart';
import 'widgets/meal_image_section.dart';
import 'widgets/meal_title_sheet.dart';

class MealTrackerScreen extends ConsumerStatefulWidget {
  const MealTrackerScreen({
    super.key,
    this.mealId,
    this.initial,
    this.initialDate,
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

  static const drinkTrackerButtonKey = Key('drink_tracker_button');
  static const mealTrackerTitleKey = Key('meal_tracker_title');
  static const mealEditSaveKey = Key('meal_tracker_save_button');

  @override
  ConsumerState<MealTrackerScreen> createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends ConsumerState<MealTrackerScreen> {
  final _titleController = TextEditingController(text: kDefaultMealTitle);
  bool _isEditingTitle = false;
  bool _mealNotFound = false;

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
      final notifier = ref.read(mealTrackerProvider.notifier);
      if (widget.mealId == null) {
        notifier.reset();
        if (widget.initialDate != null) {
          notifier.setTrackedAt(buildTrackedAt(widget.initialDate));
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
      _titleController.text = meal.title;
    });
  }

  /// Looks up a meal by id in the currently loaded [entriesProvider] state.
  /// Returns `null` if no matching meal is present.
  MealEntry? _lookupMeal(String id) {
    final entries = ref.read(entriesProvider);
    return entries.meals.where((m) => m.id == id).firstOrNull;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(mealTrackerProvider.notifier);
    notifier.setTitle(_titleController.text);

    // Edit mode with no changes → silent pop. Avoids a pointless network
    // round-trip and keeps the UX honest.
    if (widget.mealId != null && !ref.read(mealTrackerProvider).isDirty) {
      if (mounted) context.popOrGoDashboard();
      return;
    }

    // If the user never named the meal, interrupt save with a prompt so the
    // entry is identifiable in the diary. Dismissing the sheet cancels save
    // entirely; "Ohne Namen speichern" proceeds with the default title.
    if (_titleController.text.trim() == kDefaultMealTitle) {
      final outcome = await showMealTitleSheet(context);
      if (!mounted) return;
      switch (outcome) {
        case null:
          return; // dismissed — abort save
        case MealTitleEntered(title: final t):
          _titleController.text = t;
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
        titleWidget: GestureDetector(
          onTap: () => setState(() => _isEditingTitle = true),
          child: _isEditingTitle
              ? TextField(
                  controller: _titleController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => setState(() => _isEditingTitle = false),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        key: MealTrackerScreen.mealTrackerTitleKey,
                        _titleController.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeTitle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    const Icon(Icons.edit, size: 16),
                  ],
                ),
        ),
        showSuccess: state.showSuccess,
        successMessage: 'Mahlzeit gespeichert!',
        successMascotAsset: AppConstants.mascotCool,
        successAction: GestureDetector(
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
        body: _buildBody(state),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Date/Time chips
          DateTimeChips(
            value: state.trackedAt,
            onChanged: notifier.setTrackedAt,
          ),
          AppConstants.gap16,

          // 2. Image capture
          MealImageSection(
            imageBytes: state.imageBytes,
            isAnalyzing: state.isAnalyzing,
            onImagePicked: (bytes, name) async {
              notifier.setImage(bytes, name);
              try {
                await notifier.analyzeImage(bytes, name);
                if (mounted) {
                  final s = ref.read(mealTrackerProvider);
                  _titleController.text = s.title;
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fehler bei der Analyse.')),
                  );
                }
              }
            },
            onClearImage: () {
              notifier.clearImage();
              _titleController.text = kDefaultMealTitle;
            },
          ),
          AppConstants.gap16,

          // 3. Ingredients
          IngredientSearch(
            ingredients: state.ingredients,
            suggestions: state.ingredientSuggestions,
            onSearch: notifier.searchIngredients,
            onAdd: notifier.addIngredient,
            onRemove: notifier.removeIngredient,
            onDeleteIngredient: (id) => notifier.deleteUserIngredient(id),
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
}
