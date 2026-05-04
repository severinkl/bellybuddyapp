import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_entry.dart';
import '../models/user_recipe.dart';
import '../providers/core_providers.dart';
import '../repositories/meal_media_repository.dart';
import '../utils/date_format_utils.dart';
import 'diary_provider.dart';
import 'entries_provider.dart';
import 'ingredient_autocomplete_provider.dart';

/// Placeholder title written to state when the user hasn't given the meal
/// a name. Save-time code checks against this sentinel to decide whether
/// to prompt the user before persisting.
const kDefaultMealTitle = 'Neue Mahlzeit';

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
  final String? notes;
  final DateTime trackedAt;

  /// The resolved image URL of the meal that was just saved (create-mode only).
  /// Set once [save] completes; null until then. Used by the success overlay to
  /// offer "Als Rezept speichern" with the correct image.
  final String? savedImageUrl;

  MealTrackerState({
    this.seed,
    this.imageUrl,
    this.title = kDefaultMealTitle,
    this.ingredients = const [],
    this.imageBytes,
    this.imageFileName,
    this.isAnalyzing = false,
    this.isSaving = false,
    this.showSuccess = false,
    this.notes,
    DateTime? trackedAt,
    this.savedImageUrl,
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
    String? notes,
    DateTime? trackedAt,
    bool clearImageUrl =
        false, // explicit clear (since ?? can't distinguish null)
    bool clearImageBytes = false,
    String? savedImageUrl,
    bool clearSavedImageUrl = false,
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
      notes: notes ?? this.notes,
      trackedAt: trackedAt ?? this.trackedAt,
      savedImageUrl: clearSavedImageUrl
          ? null
          : (savedImageUrl ?? this.savedImageUrl),
    );
  }
}

class MealTrackerNotifier extends Notifier<MealTrackerState> {
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

  /// Pre-fills the tracker from a saved recipe (create-mode only).
  /// Clears any locally-picked image bytes/name so they don't leak into a
  /// subsequent save; sets the recipe's remote image URL instead.
  void prefillFromRecipe(UserRecipe recipe) {
    // Always clear the old imageUrl first so that a recipe with no image
    // doesn't retain a previously loaded remote URL.
    state = state.copyWith(
      title: recipe.title,
      ingredients: List.of(recipe.ingredients),
      clearImageUrl: recipe.imageUrl == null,
      imageUrl: recipe.imageUrl,
      clearImageBytes: true,
    );
  }

  void setTitle(String title) => state = state.copyWith(title: title);
  void setNotes(String? notes) => state = state.copyWith(notes: notes);
  void setTrackedAt(DateTime dt) => state = state.copyWith(trackedAt: dt);

  @visibleForTesting
  void markShowSuccess() => state = state.copyWith(showSuccess: true);

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

  void addIngredient(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.ingredients.contains(trimmed)) return;
    state = state.copyWith(ingredients: [...state.ingredients, trimmed]);
    ref.read(ingredientAutocompleteProvider.notifier).addIngredient(trimmed);
  }

  void removeIngredient(String name) {
    state = state.copyWith(
      ingredients: state.ingredients.where((i) => i != name).toList(),
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
      // savedImageUrl is stored so the success overlay can offer
      // "Als Rezept speichern" with the correct image.
      state = state.copyWith(
        isSaving: false,
        showSuccess: existingSeed == null,
        savedImageUrl: existingSeed == null ? resolvedImageUrl : null,
        clearSavedImageUrl: existingSeed != null,
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
