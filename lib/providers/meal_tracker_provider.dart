import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../providers/core_providers.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/meal_media_repository.dart';
import '../services/ingredient_service.dart';
import '../utils/logger.dart';
import 'entries_provider.dart';

class MealTrackerState {
  final String title;
  final List<String> ingredients;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool isAnalyzing;
  final bool isSaving;
  final bool showSuccess;
  final List<IngredientSuggestion> ingredientSuggestions;
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
    List<IngredientSuggestion>? ingredientSuggestions,
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
      ingredientSuggestions:
          ingredientSuggestions ?? this.ingredientSuggestions,
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

  void clearImage() {
    state = MealTrackerState(trackedAt: state.trackedAt, notes: state.notes);
  }

  Future<void> analyzeImage(Uint8List bytes, String filename) async {
    state = state.copyWith(isAnalyzing: true);
    try {
      final result = await ref
          .read(mealMediaRepositoryProvider)
          .analyzeMealImage(bytes, filename);

      state = state.copyWith(
        title: result['title'] as String? ?? state.title,
        ingredients: result['ingredients'] != null
            ? List<String>.from(result['ingredients'] as List? ?? [])
            : state.ingredients,
        isAnalyzing: false,
      );
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      rethrow;
    }
  }

  Future<void> searchIngredients(String query) async {
    if (query.length < 3) {
      state = state.copyWith(ingredientSuggestions: []);
      return;
    }
    state = state.copyWith(ingredientSearchError: null);
    try {
      final userId = ref.read(currentUserIdProvider);
      final results = await ref
          .read(ingredientRepositoryProvider)
          .search(query, userId: userId);
      state = state.copyWith(ingredientSuggestions: results);
    } catch (e, st) {
      _log.error('ingredient search failed', e, st);
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
    // Write new ingredient to DB (fire-and-forget)
    final userId = ref.read(currentUserIdProvider);
    ref
        .read(ingredientRepositoryProvider)
        .insertIfNew(trimmed, userId: userId)
        .ignore();
  }

  void removeIngredient(String name) {
    state = state.copyWith(
      ingredients: state.ingredients.where((i) => i != name).toList(),
    );
  }

  Future<void> deleteUserIngredient(String id) async {
    await ref.read(ingredientRepositoryProvider).deleteUserIngredient(id);
    state = state.copyWith(
      ingredientSuggestions: state.ingredientSuggestions
          .where((s) => s.id != id)
          .toList(),
    );
  }

  Future<void> save() async {
    state = state.copyWith(isSaving: true);
    try {
      String? imageUrl;
      if (state.imageBytes != null && state.imageFileName != null) {
        final ext = state.imageFileName!.split('.').last;
        imageUrl = await ref
            .read(mealMediaRepositoryProvider)
            .uploadMealImage(
              userId: ref.read(currentUserIdProvider)!,
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
      ref.read(mealMediaRepositoryProvider).triggerSuggestionRefresh();

      state = state.copyWith(isSaving: false, showSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final mealTrackerProvider =
    NotifierProvider<MealTrackerNotifier, MealTrackerState>(
      MealTrackerNotifier.new,
    );
