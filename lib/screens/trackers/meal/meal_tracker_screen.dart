import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../providers/meal_tracker_provider.dart';
import '../../../router/route_names.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_success_overlay.dart';
import '../../../widgets/common/date_time_picker_tile.dart';

class MealTrackerScreen extends ConsumerStatefulWidget {
  const MealTrackerScreen({super.key});

  @override
  ConsumerState<MealTrackerScreen> createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends ConsumerState<MealTrackerScreen> {
  final _titleController = TextEditingController(text: 'Neue Mahlzeit');
  final _notesController = TextEditingController();
  final _ingredientController = TextEditingController();
  final _picker = ImagePicker();
  bool _isEditingTitle = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final notifier = ref.read(mealTrackerProvider.notifier);
    notifier.setImage(bytes, file.name);

    try {
      await notifier.analyzeImage(bytes, file.name);
      if (mounted) {
        final state = ref.read(mealTrackerProvider);
        _titleController.text = state.title;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler bei der Analyse.')),
        );
      }
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(mealTrackerProvider.notifier);
    notifier.setTitle(_titleController.text);
    notifier.setNotes(_notesController.text.isEmpty ? null : _notesController.text);

    await saveWithFeedback(
      context,
      () => notifier.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealTrackerProvider);

    if (state.showSuccess) {
      return BbSuccessOverlay(
        message: 'Mahlzeit gespeichert!',
        onDismissed: () {
          if (mounted) context.go(RoutePaths.dashboard);
        },
        action: ElevatedButton(
          onPressed: () => context.push(RoutePaths.drinkTracker),
          child: const Text('Getränk dazu tracken'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: _isEditingTitle
            ? TextField(
                controller: _titleController,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => setState(() => _isEditingTitle = false),
              )
            : GestureDetector(
                onTap: () => setState(() => _isEditingTitle = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_titleController.text),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 16),
                  ],
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image capture
            GestureDetector(
              onTap: () => _showImageSourceSheet(),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  image: state.imageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(state.imageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: state.imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 48, color: AppTheme.mutedForeground),
                          SizedBox(height: 8),
                          Text('Foto aufnehmen', style: TextStyle(color: AppTheme.mutedForeground)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            if (state.isAnalyzing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 8),
                      Text('KI analysiert...', style: TextStyle(color: AppTheme.mutedForeground)),
                    ],
                  ),
                ),
              ),

            // Ingredients
            const Text(
              'Zutaten',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientController,
              decoration: InputDecoration(
                hintText: 'Zutat hinzufügen...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    ref.read(mealTrackerProvider.notifier).addIngredient(_ingredientController.text);
                    _ingredientController.clear();
                  },
                ),
              ),
              onChanged: (v) => ref.read(mealTrackerProvider.notifier).searchIngredients(v),
              onSubmitted: (v) {
                ref.read(mealTrackerProvider.notifier).addIngredient(v);
                _ingredientController.clear();
              },
            ),

            if (state.ingredientSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: state.ingredientSuggestions.map((s) {
                    return ListTile(
                      title: Text(s),
                      dense: true,
                      onTap: () {
                        ref.read(mealTrackerProvider.notifier).addIngredient(s);
                        _ingredientController.clear();
                      },
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  onDeleted: () =>
                      ref.read(mealTrackerProvider.notifier).removeIngredient(ingredient),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date/Time
            DateTimePickerTile(
              value: state.trackedAt,
              onChanged: (dt) => ref.read(mealTrackerProvider.notifier).setTrackedAt(dt),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notizen (optional)...',
              ),
            ),
            const SizedBox(height: 24),

            // Save
            BbButton(
              label: 'Mahlzeit speichern',
              isLoading: state.isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
