import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/meal_tracker_provider.dart';
import '../../../router/route_names.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/date_time_picker_tile.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import 'widgets/ingredient_search.dart';
import 'widgets/meal_image_section.dart';

class MealTrackerScreen extends ConsumerStatefulWidget {
  const MealTrackerScreen({super.key});

  @override
  ConsumerState<MealTrackerScreen> createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends ConsumerState<MealTrackerScreen> {
  final _titleController = TextEditingController(text: 'Neue Mahlzeit');
  bool _isEditingTitle = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(mealTrackerProvider.notifier);
    notifier.setTitle(_titleController.text);

    await saveWithFeedback(
      context,
      () => notifier.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealTrackerProvider);

    return TrackerScreenScaffold(
      title: _isEditingTitle ? '' : _titleController.text,
      showSuccess: state.showSuccess,
      successMessage: 'Mahlzeit gespeichert!',
      successMascotAsset: AppConstants.mascotCool,
      successAction: GestureDetector(
        onTap: () => context.push(RoutePaths.drinkTracker),
        child: const Text('Getränk hinzufügen'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(MealTrackerState state) {
    final canSave =
        state.ingredients.isNotEmpty && !state.isAnalyzing && !state.isSaving;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Editable title
              GestureDetector(
                onTap: () => setState(() => _isEditingTitle = true),
                child: _isEditingTitle
                    ? TextField(
                        controller: _titleController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) =>
                            setState(() => _isEditingTitle = false),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _titleController.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 16),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // 2. Date/Time (moved before image)
              DateTimePickerTile(
                value: state.trackedAt,
                onChanged: (dt) =>
                    ref.read(mealTrackerProvider.notifier).setTrackedAt(dt),
              ),
              const SizedBox(height: 16),

              // 3. Image capture
              MealImageSection(
                imageBytes: state.imageBytes,
                isAnalyzing: state.isAnalyzing,
                onImagePicked: (bytes, name) async {
                  final notifier = ref.read(mealTrackerProvider.notifier);
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
                        const SnackBar(
                            content: Text('Fehler bei der Analyse.')),
                      );
                    }
                  }
                },
                onClearImage: () {
                  ref.read(mealTrackerProvider.notifier).clearImage();
                  _titleController.text = 'Neue Mahlzeit';
                },
              ),
              const SizedBox(height: 16),

              // 4. Ingredients
              IngredientSearch(
                ingredients: state.ingredients,
                suggestions: state.ingredientSuggestions,
                onSearch:
                    ref.read(mealTrackerProvider.notifier).searchIngredients,
                onAdd: ref.read(mealTrackerProvider.notifier).addIngredient,
                onRemove:
                    ref.read(mealTrackerProvider.notifier).removeIngredient,
                onDeleteIngredient: (id) => ref
                    .read(mealTrackerProvider.notifier)
                    .deleteUserIngredient(id),
              ),
            ],
          ),
        ),

        // Fixed bottom bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.screenBackground.withValues(alpha: 0.0),
                  AppTheme.screenBackground,
                ],
                stops: const [0.0, 0.3],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Getränk dazu tracken" link
                GestureDetector(
                  onTap: () => context.push(RoutePaths.drinkTracker),
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop_outlined,
                            size: 18, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text(
                          'Getränk dazu tracken',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Save button
                BbButton(
                  label: 'Speichern',
                  isLoading: state.isSaving,
                  onPressed: canSave ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
