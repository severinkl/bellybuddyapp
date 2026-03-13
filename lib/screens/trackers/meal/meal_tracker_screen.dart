import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../models/meal_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/edge_function_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_success_overlay.dart';

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
  DateTime _trackedAt = DateTime.now();
  List<String> _ingredients = [];
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _showSuccess = false;
  bool _isEditingTitle = false;
  List<String> _ingredientSuggestions = [];

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
    setState(() {
      _imageFile = file;
      _imageBytes = bytes;
    });

    _analyzeImage(bytes, file.name);
  }

  Future<void> _analyzeImage(Uint8List bytes, String filename) async {
    setState(() => _isAnalyzing = true);
    try {
      final ext = filename.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final result = await EdgeFunctionService.invoke('analyze-meal', body: {
        'imageBase64': base64,
      });

      if (mounted) {
        setState(() {
          if (result['title'] != null) {
            _titleController.text = result['title'] as String;
          }
          if (result['ingredients'] != null) {
            _ingredients = List<String>.from(result['ingredients'] as List);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler bei der Analyse.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _searchIngredients(String query) async {
    if (query.length < 2) {
      setState(() => _ingredientSuggestions = []);
      return;
    }
    try {
      final data = await SupabaseService.client
          .from('ingredients')
          .select('name')
          .ilike('name', '%$query%')
          .limit(10);
      setState(() {
        _ingredientSuggestions =
            (data as List).map((e) => e['name'] as String).toList();
      });
    } catch (_) {}
  }

  void _addIngredient(String name) {
    if (name.trim().isEmpty || _ingredients.contains(name.trim())) return;
    setState(() {
      _ingredients.add(name.trim());
      _ingredientController.clear();
      _ingredientSuggestions = [];
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      String? imageUrl;
      if (_imageBytes != null && _imageFile != null) {
        final ext = _imageFile!.name.split('.').last;
        imageUrl = await StorageService.uploadImage(
          bucket: 'meal-images',
          userId: SupabaseService.userId!,
          fileBytes: _imageBytes!,
          extension: ext,
        );
      }

      final meal = MealEntry(
        id: const Uuid().v4(),
        trackedAt: _trackedAt,
        title: _titleController.text,
        ingredients: _ingredients,
        imageUrl: imageUrl,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await ref.read(entriesProvider.notifier).addMeal(meal);

      // Fire and forget
      EdgeFunctionService.invoke('refresh-ingredient-suggestions').ignore();

      setState(() => _showSuccess = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
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
                  image: _imageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_imageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageBytes == null
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

            if (_isAnalyzing)
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
                  onPressed: () => _addIngredient(_ingredientController.text),
                ),
              ),
              onChanged: _searchIngredients,
              onSubmitted: _addIngredient,
            ),

            if (_ingredientSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: _ingredientSuggestions.map((s) {
                    return ListTile(
                      title: Text(s),
                      dense: true,
                      onTap: () => _addIngredient(s),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  onDeleted: () {
                    setState(() => _ingredients.remove(ingredient));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date/Time
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                '${_trackedAt.day}.${_trackedAt.month}.${_trackedAt.year} '
                '${_trackedAt.hour.toString().padLeft(2, '0')}:'
                '${_trackedAt.minute.toString().padLeft(2, '0')} Uhr',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _trackedAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('de'),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_trackedAt),
                  );
                  if (time != null) {
                    setState(() {
                      _trackedAt = DateTime(
                        date.year, date.month, date.day,
                        time.hour, time.minute,
                      );
                    });
                  }
                }
              },
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
              isLoading: _isSaving,
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
