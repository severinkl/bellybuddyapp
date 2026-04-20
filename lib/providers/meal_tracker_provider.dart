import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../providers/core_providers.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/meal_media_repository.dart';
import '../models/ingredient_search_result.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'diary_provider.dart';
import 'entries_provider.dart';

class MealTrackerState {
  final MealEntry? seed; // null = create; non-null = edit
  final String? imageUrl; // existing remote URL (edit mode seed)
  final String title;
  final List<String> ingredients;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool isAnalyzing;
  final bool isSaving;
  final bool showSuccess;
  final List<IngredientSearchResult> ingredientSuggestions;
  final Object? ingredientSearchError;
  final String? notes;
  final DateTime trackedAt;

  MealTrackerState({
    this.seed,
    this.imageUrl,
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

  /// True only in edit mode when any seeded field has been modified.
  /// In create mode ([seed] is null) this always returns false — dirty
  /// tracking is only meaningful when we have a baseline to compare against.
  bool get isDirty {
    final s = seed;
    if (s == null) return false;
    return title != s.title ||
        !_listEq(ingredients, s.ingredients) ||
        notes != s.notes ||
        trackedAt != s.trackedAt ||
        imageBytes != null || // picked a new image
        imageUrl != s.imageUrl; // cleared or swapped the image
  }

  // Ingredient order is not user-meaningful (chips render in insertion order but
  // mean the same meal regardless), so dirty-tracking uses set equality.
  static bool _listEq(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  MealTrackerState copyWith({
    MealEntry? seed,
    String? imageUrl,
    String? title,
    List<String>? ingredients,
    Uint8List? imageBytes,
    String? imageFileName,
    bool? isAnalyzing,
    bool? isSaving,
    bool? showSuccess,
    List<IngredientSearchResult>? ingredientSuggestions,
    Object? ingredientSearchError,
    String? notes,
    DateTime? trackedAt,
    bool clearImageUrl =
        false, // explicit clear (since ?? can't distinguish null)
    bool clearImageBytes = false,
  }) {
    return MealTrackerState(
      seed: seed ?? this.seed,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
      imageFileName: clearImageBytes
          ? null
          : (imageFileName ?? this.imageFileName),
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

  /// Reset to fresh state — call when opening the tracker screen
  void reset() => state = MealTrackerState(trackedAt: DateTime.now());

  /// Seed the state from an existing meal for edit mode.
  void seed(MealEntry meal) {
    state = MealTrackerState(
      seed: meal,
      title: meal.title,
      ingredients: List<String>.from(meal.ingredients),
      imageUrl: meal.imageUrl,
      notes: meal.notes,
      trackedAt: meal.trackedAt,
    );
  }

  void setTitle(String title) => state = state.copyWith(title: title);
  void setNotes(String? notes) => state = state.copyWith(notes: notes);
  void setTrackedAt(DateTime dt) => state = state.copyWith(trackedAt: dt);

  void setImage(Uint8List bytes, String fileName) {
    // Clear the remote URL so UI reading state.imageUrl doesn't render the
    // stale seed image under the new local preview. save() re-derives the
    // URL from the upload.
    state = state.copyWith(
      imageBytes: bytes,
      imageFileName: fileName,
      clearImageUrl: true,
    );
  }

  void clearImage() {
    state = state.copyWith(clearImageBytes: true, clearImageUrl: true);
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
      final existingSeed = state.seed;

      String? resolvedImageUrl = state.imageUrl;
      if (state.imageBytes != null && state.imageFileName != null) {
        final ext = state.imageFileName!.split('.').last;
        resolvedImageUrl = await ref
            .read(mealMediaRepositoryProvider)
            .uploadMealImage(
              userId: ref.read(currentUserIdProvider)!,
              fileBytes: state.imageBytes!,
              extension: ext,
            );
      }

      final meal = MealEntry(
        id: existingSeed?.id ?? const Uuid().v4(),
        trackedAt: state.trackedAt,
        title: state.title,
        ingredients: state.ingredients,
        imageUrl: resolvedImageUrl,
        notes: state.notes,
      );

      if (existingSeed == null) {
        await ref.read(entriesProvider.notifier).addMeal(meal);
      } else {
        await ref.read(entriesProvider.notifier).updateMeal(meal);
      }

      // Invalidate affected diary days (new date always; old date too if it moved).
      final newDay = startOfDay(state.trackedAt);
      ref.invalidate(diaryEntriesProvider(newDay));
      if (existingSeed != null &&
          !isSameDay(existingSeed.trackedAt, state.trackedAt)) {
        ref.invalidate(
          diaryEntriesProvider(startOfDay(existingSeed.trackedAt)),
        );
      }

      // Fire and forget
      ref.read(mealMediaRepositoryProvider).triggerSuggestionRefresh();

      // showSuccess is the create-mode "nice job" screen. Edit mode pops
      // instead — the screen listens to isSaving transitions and pops.
      state = state.copyWith(
        isSaving: false,
        showSuccess: existingSeed == null,
      );
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
