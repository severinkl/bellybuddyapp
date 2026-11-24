import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/meal_entry.dart';
import '../../providers/core_providers.dart';
import '../../providers/ingredient_autocomplete_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../repositories/meal_media_repository.dart';
import '../../services/user_recipe_service.dart';
import '../../utils/logger.dart';
import '../../utils/save_helper.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/editable_app_bar_title.dart';
import '../../widgets/common/ingredient_search.dart';
import '../trackers/meal/widgets/meal_image_section.dart';
import 'widgets/recipe_steps_editor.dart';

class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId, this.initialMeal})
    : assert(
        recipeId == null || initialMeal == null,
        'initialMeal is only valid in create mode (recipeId == null).',
      );

  /// Null → create mode. Non-null → edit mode (prefills from provider).
  final String? recipeId;

  /// In create mode, pre-fills title, ingredients, and image from this meal.
  /// Must be null when [recipeId] is non-null (enforced by an assert).
  final MealEntry? initialMeal;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  static const _log = AppLogger('RecipeEditorScreen');

  String _title = '';
  List<String> _ingredients = [];
  String? _imageUrl; // existing URL (edit mode)
  Uint8List? _imageBytes; // freshly picked local bytes
  String? _imageFileName;
  bool _isSaving = false;

  /// The steps' raw texts as typed; [_loadedSteps] are the saved recipe's.
  List<String> _steps = [];
  List<String> _loadedSteps = [];

  /// Ingredient name → its amount, from the loaded recipe; an ingredient
  /// added here has none. Sent again only when the recipe had amounts.
  final Map<String, String?> _amounts = {};
  bool _hadAmounts = false;
  bool _prefilled = false;

  bool get _isEditMode => widget.recipeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Trigger a fetch so the provider has data, then prefill.
        await ref.read(userRecipesProvider.notifier).fetch();
        if (!mounted) return;
        _prefillFromProvider();
      });
    } else if (widget.initialMeal != null) {
      final meal = widget.initialMeal!;
      _title = meal.title;
      _ingredients = List<String>.from(meal.ingredients);
      _imageUrl = meal.imageUrl;
    }
  }

  void _prefillFromProvider() {
    final recipes = ref.read(userRecipesProvider).value;
    if (recipes == null) return;
    final recipe = recipes.where((r) => r.id == widget.recipeId).firstOrNull;
    if (recipe == null) return;
    setState(() {
      _title = recipe.title;
      _ingredients = List<String>.from(recipe.ingredients);
      _imageUrl = recipe.imageUrl;
      _steps = List<String>.from(recipe.instructions);
      _loadedSteps = recipe.instructions;
      _hadAmounts = recipe.ingredientAmounts != null;
      _amounts.clear();
      for (var i = 0; i < recipe.ingredients.length; i++) {
        _amounts[recipe.ingredients[i]] = recipe.amountOf(i);
      }
      _prefilled = true;
    });
  }

  Future<void> _save() async {
    await flushFocusBeforeSave();
    if (!mounted) return;

    final title = _title.trim();
    if (title.isEmpty || _ingredients.isEmpty) return;

    final steps = [
      for (final text in _steps)
        if (text.trim().isNotEmpty) text.trim(),
    ];
    if (steps.fold<int>(0, (sum, s) => sum + s.length) >
        AppConstants.recipeStepsMaxChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Zubereitung ist zu lang. Bitte kürze sie.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? resolvedImageUrl = _imageUrl;
      if (_imageBytes != null) {
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) {
          final extension = _imageFileName?.split('.').last ?? 'jpg';
          resolvedImageUrl = await ref
              .read(mealMediaRepositoryProvider)
              .uploadMealImage(
                userId: userId,
                fileBytes: _imageBytes!,
                extension: extension,
              );
        }
      }

      final notifier = ref.read(userRecipesProvider.notifier);
      if (_isEditMode) {
        await notifier.update(
          id: widget.recipeId!,
          title: title,
          ingredients: _ingredients,
          imageUrl: resolvedImageUrl,
          instructions: listEquals(steps, _loadedSteps) ? null : steps,
          ingredientAmounts: _amountsToSend(),
        );
      } else {
        await notifier.create(
          title: title,
          ingredients: _ingredients,
          imageUrl: resolvedImageUrl,
          instructions: steps,
        );
      }

      if (mounted) context.pop();
    } on DuplicateRecipeTitleException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Du hast bereits ein Rezept mit diesem Titel.'),
          ),
        );
      }
    } catch (e, st) {
      _log.error('save failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The amounts aligned with the ingredients that are left, or null when
  /// the recipe had none (or no ingredient has one any more).
  List<String?>? _amountsToSend() {
    if (!_hadAmounts) return null;
    final amounts = [for (final name in _ingredients) _amounts[name]];
    return amounts.every((a) => a == null) ? null : amounts;
  }

  @override
  Widget build(BuildContext context) {
    final titleEmpty = _title.trim().isEmpty;
    final ingredientsEmpty = _ingredients.isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
          onPressed: () => context.pop(),
        ),
        title: EditableAppBarTitle(
          initialTitle: _title,
          placeholder: 'Rezept benennen',
          autofocusOnMount: !_isEditMode && widget.initialMeal == null,
          onTextChanged: (v) => setState(() => _title = v),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppConstants.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MealImageSection(
                      imageBytes: _imageBytes,
                      isAnalyzing: false,
                      initialImageUrl: _imageUrl,
                      onImagePicked: (bytes, name) async => setState(() {
                        _imageBytes = bytes;
                        _imageFileName = name;
                        _imageUrl = null;
                      }),
                      onClearImage: () => setState(() {
                        _imageBytes = null;
                        _imageFileName = null;
                        _imageUrl = null;
                      }),
                    ),
                    AppConstants.gap16,
                    Consumer(
                      builder: (context, ref, _) {
                        final autocomplete = ref.watch(
                          ingredientAutocompleteProvider,
                        );
                        final autocompleteNotifier = ref.read(
                          ingredientAutocompleteProvider.notifier,
                        );
                        return IngredientSearch(
                          ingredients: _ingredients,
                          suggestions: autocomplete.suggestions,
                          onSearch: autocompleteNotifier.searchIngredients,
                          onAdd: (name) {
                            if (_ingredients.contains(name)) return;
                            setState(
                              () => _ingredients = [..._ingredients, name],
                            );
                            autocompleteNotifier.addIngredient(name);
                          },
                          onRemove: (name) => setState(() {
                            _ingredients = _ingredients
                                .where((i) => i != name)
                                .toList();
                          }),
                          onDeleteIngredient:
                              autocompleteNotifier.deleteUserIngredient,
                        );
                      },
                    ),
                    AppConstants.gap16,
                    RecipeStepsEditor(
                      key: ValueKey('steps_$_prefilled'),
                      initial: _steps,
                      onChanged: (steps) => _steps = steps,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: AppConstants.paddingMd,
              child: BbButton(
                label: 'Speichern',
                isLoading: _isSaving,
                onPressed: titleEmpty || ingredientsEmpty || _isSaving
                    ? null
                    : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
