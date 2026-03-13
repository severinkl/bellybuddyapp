import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../services/edge_function_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import '../utils/mime_utils.dart';
import 'entries_provider.dart';

class MealTrackerState {
  final String title;
  final List<String> ingredients;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool isAnalyzing;
  final bool isSaving;
  final bool showSuccess;
  final List<String> ingredientSuggestions;
  final Object? ingredientSearchError;
  final String? notes;
  final DateTime trackedAt;

  MealTrackerState({
    this.title = 'Neue Mahlzeit',
    this.ingredients = const [],
    this.imageBytes,
    this.imageFileName,
    this.isAnalyzing = false,
    this.isSaving = false,
    this.showSuccess = false,
    this.ingredientSuggestions = const [],
    this.ingredientSearchError,
    this.notes,
    DateTime? trackedAt,
  }) : trackedAt = trackedAt ?? DateTime.now();

  MealTrackerState copyWith({
    String? title,
    List<String>? ingredients,
    Uint8List? imageBytes,
    String? imageFileName,
    bool? isAnalyzing,
    bool? isSaving,
    bool? showSuccess,
    List<String>? ingredientSuggestions,
    Object? ingredientSearchError,
    String? notes,
    DateTime? trackedAt,
  }) {
    return MealTrackerState(
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      imageBytes: imageBytes ?? this.imageBytes,
      imageFileName: imageFileName ?? this.imageFileName,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isSaving: isSaving ?? this.isSaving,
      showSuccess: showSuccess ?? this.showSuccess,
      ingredientSuggestions: ingredientSuggestions ?? this.ingredientSuggestions,
      ingredientSearchError: ingredientSearchError,
      notes: notes ?? this.notes,
      trackedAt: trackedAt ?? this.trackedAt,
    );
  }
}

class MealTrackerNotifier extends Notifier<MealTrackerState> {
  static const _log = AppLogger('MealTracker');
  @override
  MealTrackerState build() => MealTrackerState(trackedAt: DateTime.now());

  void setTitle(String title) => state = state.copyWith(title: title);
  void setNotes(String? notes) => state = state.copyWith(notes: notes);
  void setTrackedAt(DateTime dt) => state = state.copyWith(trackedAt: dt);

  void setImage(Uint8List bytes, String fileName) {
    state = state.copyWith(imageBytes: bytes, imageFileName: fileName);
  }

  Future<void> analyzeImage(Uint8List bytes, String filename) async {
    state = state.copyWith(isAnalyzing: true);
    try {
      final ext = filename.split('.').last.toLowerCase();
      final mimeType = mimeTypeForExtension(ext);
      final base64Data = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final result = await EdgeFunctionService.invoke('analyze-meal', body: {
        'imageBase64': base64Data,
      });

      state = state.copyWith(
        title: result['title'] as String? ?? state.title,
        ingredients: result['ingredients'] != null
            ? List<String>.from(result['ingredients'] as List)
            : state.ingredients,
        isAnalyzing: false,
      );
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      rethrow;
    }
  }

  Future<void> searchIngredients(String query) async {
    if (query.length < 2) {
      state = state.copyWith(ingredientSuggestions: []);
      return;
    }
    state = state.copyWith(ingredientSearchError: null);
    try {
      final data = await SupabaseService.client
          .from('ingredients')
          .select('name')
          .ilike('name', '%$query%')
          .limit(10);
      state = state.copyWith(
        ingredientSuggestions:
            (data as List).map((e) => e['name'] as String).toList(),
      );
    } catch (e) {
      _log.error('ingredient search failed', e);
      state = state.copyWith(ingredientSearchError: e);
    }
  }

  void addIngredient(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.ingredients.contains(trimmed)) return;
    state = state.copyWith(
      ingredients: [...state.ingredients, trimmed],
      ingredientSuggestions: [],
    );
  }

  void removeIngredient(String name) {
    state = state.copyWith(
      ingredients: state.ingredients.where((i) => i != name).toList(),
    );
  }

  Future<void> save() async {
    state = state.copyWith(isSaving: true);
    try {
      String? imageUrl;
      if (state.imageBytes != null && state.imageFileName != null) {
        final ext = state.imageFileName!.split('.').last;
        imageUrl = await StorageService.uploadImage(
          bucket: 'meal-images',
          userId: SupabaseService.userId!,
          fileBytes: state.imageBytes!,
          extension: ext,
        );
      }

      final meal = MealEntry(
        id: const Uuid().v4(),
        trackedAt: state.trackedAt,
        title: state.title,
        ingredients: state.ingredients,
        imageUrl: imageUrl,
        notes: state.notes,
      );

      await ref.read(entriesProvider.notifier).addMeal(meal);

      // Fire and forget
      EdgeFunctionService.invoke('refresh-ingredient-suggestions').ignore();

      state = state.copyWith(isSaving: false, showSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final mealTrackerProvider =
    NotifierProvider<MealTrackerNotifier, MealTrackerState>(MealTrackerNotifier.new);
