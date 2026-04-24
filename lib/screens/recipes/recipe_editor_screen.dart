import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/core_providers.dart';
import '../../providers/user_recipes_provider.dart';
import '../../repositories/meal_media_repository.dart';
import '../../utils/logger.dart';
import '../../widgets/common/bb_button.dart';

class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});

  /// Null → create mode. Non-null → edit mode (prefills from provider).
  final String? recipeId;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  static const _log = AppLogger('RecipeEditorScreen');

  final _titleController = TextEditingController();
  final _ingredientController = TextEditingController();

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
      _titleController.text = recipe.title;
      _ingredients = List<String>.from(recipe.ingredients);
      _imageUrl = recipe.imageUrl;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageFileName = file.name;
      _imageUrl = null; // local bytes take precedence
    });
  }

  void _addIngredient() {
    final value = _ingredientController.text.trim();
    if (value.isEmpty || _ingredients.contains(value)) return;
    setState(() {
      _ingredients = [..._ingredients, value];
      _ingredientController.clear();
    });
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients = _ingredients.where((i) => i != ingredient).toList();
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // Upload local image bytes if the user picked a new image.
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
    final titleEmpty = _titleController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditMode ? 'Rezept bearbeiten' : 'Neues Rezept'),
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
                    // Title field
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Titel',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                    ),
                    AppConstants.gap16,

                    // Image section
                    _buildImageSection(),
                    AppConstants.gap16,

                    // Ingredient section
                    _buildIngredientSection(),
                  ],
                ),
              ),
            ),

            // Save button
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

  Widget _buildImageSection() {
    if (_imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: AppConstants.spacing12,
            right: AppConstants.spacing12,
            child: GestureDetector(
              onTap: () => setState(() {
                _imageBytes = null;
                _imageFileName = null;
              }),
              child: Container(
                width: AppConstants.iconBadgeSm,
                height: AppConstants.iconBadgeSm,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    if (_imageUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: _imageUrl!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: AppConstants.spacing12,
            right: AppConstants.spacing12,
            child: GestureDetector(
              onTap: () => setState(() => _imageUrl = null),
              child: Container(
                width: AppConstants.iconBadgeSm,
                height: AppConstants.iconBadgeSm,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    // Empty state — pick from camera or gallery
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Kamera'),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galerie'),
        ),
      ],
    );
  }

  Widget _buildIngredientSection() {
    return Container(
      padding: AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zutaten',
            style: TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap8,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredientController,
                  decoration: const InputDecoration(
                    hintText: 'Zutat eingeben',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingSm,
                    ),
                  ),
                  style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                  onSubmitted: (_) => _addIngredient(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              OutlinedButton(
                onPressed: _addIngredient,
                child: const Text('Hinzufügen'),
              ),
            ],
          ),
          if (_ingredients.isNotEmpty) ...[
            AppConstants.gap8,
            Wrap(
              spacing: AppConstants.spacingSm,
              runSpacing: AppConstants.spacingSm,
              children: [
                for (final ingredient in _ingredients)
                  Chip(
                    label: Text(ingredient),
                    onDeleted: () => _removeIngredient(ingredient),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
