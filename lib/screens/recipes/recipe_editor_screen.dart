import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/core_providers.dart';
import '../../providers/ingredient_autocomplete_provider.dart';
import '../../providers/user_recipes_provider.dart';
import '../../repositories/meal_media_repository.dart';
import '../../utils/logger.dart';
import '../../utils/save_helper.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/editable_app_bar_title.dart';
import '../../widgets/common/ingredient_search.dart';
import '../trackers/meal/widgets/meal_image_section.dart';

class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});

  /// Null → create mode. Non-null → edit mode (prefills from provider).
  final String? recipeId;

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
    });
  }

  Future<void> _save() async {
    await flushFocusBeforeSave();
    if (!mounted) return;

    final title = _title.trim();
    if (title.isEmpty) return;

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
        );
      } else {
        await notifier.create(
          title: title,
          ingredients: _ingredients,
          imageUrl: resolvedImageUrl,
        );
      }

      if (mounted) context.pop();
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

  @override
  Widget build(BuildContext context) {
    final titleEmpty = _title.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: EditableAppBarTitle(
          initialTitle: _title,
          placeholder: 'Rezept benennen',
          autofocusOnMount: !_isEditMode,
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
                  ],
                ),
              ),
            ),

            Padding(
              padding: AppConstants.paddingMd,
              child: BbButton(
                label: 'Speichern',
                isLoading: _isSaving,
                onPressed: titleEmpty || _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
