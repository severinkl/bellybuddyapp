import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../services/entry_crud_service.dart';
import '../services/entry_query_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';

/// State holding all entries for a given date range
class EntriesState {
  final List<MealEntry> meals;
  final List<ToiletEntry> toiletEntries;
  final List<GutFeelingEntry> gutFeelings;
  final List<DrinkEntry> drinks;
  final bool isLoading;
  final Object? error;

  const EntriesState({
    this.meals = const [],
    this.toiletEntries = const [],
    this.gutFeelings = const [],
    this.drinks = const [],
    this.isLoading = false,
    this.error,
  });

  EntriesState copyWith({
    List<MealEntry>? meals,
    List<ToiletEntry>? toiletEntries,
    List<GutFeelingEntry>? gutFeelings,
    List<DrinkEntry>? drinks,
    bool? isLoading,
    Object? error,
  }) {
    return EntriesState(
      meals: meals ?? this.meals,
      toiletEntries: toiletEntries ?? this.toiletEntries,
      gutFeelings: gutFeelings ?? this.gutFeelings,
      drinks: drinks ?? this.drinks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EntriesNotifier extends Notifier<EntriesState> {
  static const _log = AppLogger('EntriesNotifier');

  @override
  EntriesState build() => const EntriesState();

  Future<void> loadEntries(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final result = await EntryQueryService.fetchEntriesForDateRange(
        userId: userId,
        date: date,
        ordered: true,
      );

      state = state.copyWith(
        meals: result.meals,
        toiletEntries: result.toiletEntries,
        gutFeelings: result.gutFeelings,
        drinks: result.drinks,
        isLoading: false,
      );
    } catch (e, st) {
      _log.error('loadEntries failed for $date', e, st);
      state = state.copyWith(isLoading: false, error: e);
      rethrow;
    }
  }

  // -- Meal CRUD --

  Future<void> addMeal(MealEntry meal) =>
      EntryCrudService.insert(entryTableFor['meal']!, meal.toJson());

  Future<void> updateMeal(MealEntry meal) =>
      EntryCrudService.update(entryTableFor['meal']!, meal.id, meal.toJson());

  Future<void> deleteMeal(String id) =>
      EntryCrudService.delete(entryTableFor['meal']!, id);

  // -- Toilet CRUD --

  Future<void> addToiletEntry(ToiletEntry entry) =>
      EntryCrudService.insert(entryTableFor['toilet']!, entry.toJson());

  Future<void> updateToiletEntry(ToiletEntry entry) =>
      EntryCrudService.update(entryTableFor['toilet']!, entry.id, entry.toJson());

  Future<void> deleteToiletEntry(String id) =>
      EntryCrudService.delete(entryTableFor['toilet']!, id);

  // -- Gut feeling CRUD --

  Future<void> addGutFeeling(GutFeelingEntry entry) =>
      EntryCrudService.insert(entryTableFor['gutFeeling']!, entry.toJson());

  Future<void> updateGutFeeling(GutFeelingEntry entry) =>
      EntryCrudService.update(entryTableFor['gutFeeling']!, entry.id, entry.toJson());

  Future<void> deleteGutFeeling(String id) =>
      EntryCrudService.delete(entryTableFor['gutFeeling']!, id);

  // -- Drink CRUD --

  Future<void> addDrinkEntry(DrinkEntry entry) =>
      EntryCrudService.insert(entryTableFor['drink']!, entry.toInsertJson());

  Future<void> updateDrinkEntry(DrinkEntry entry) =>
      EntryCrudService.update(entryTableFor['drink']!, entry.id, entry.toInsertJson());

  Future<void> deleteDrinkEntry(String id) =>
      EntryCrudService.delete(entryTableFor['drink']!, id);

  // -- Generic delete by type (used by diary) --

  Future<void> deleteByType(String type, String id) =>
      EntryCrudService.deleteByType(type, id);

  // -- Typed update by ID (used by diary detail sheets) --

  Future<void> updateGutFeelingById(
    String id, {
    required int bloating,
    required int gas,
    required int cramps,
    required int fullness,
    int? stress,
    int? happiness,
    int? energy,
    int? focus,
    int? bodyFeel,
  }) =>
      EntryCrudService.update(entryTableFor['gutFeeling']!, id, {
        'bloating': bloating,
        'gas': gas,
        'cramps': cramps,
        'fullness': fullness,
        'stress': stress,
        'happiness': happiness,
        'energy': energy,
        'focus': focus,
        'body_feel': bodyFeel,
      });

  Future<void> updateToiletById(
    String id, {
    required int stoolType,
  }) =>
      EntryCrudService.update(entryTableFor['toilet']!, id, {
        'stool_type': stoolType,
      });

  Future<void> updateDrinkById(
    String id, {
    required int amountMl,
    String? notes,
  }) =>
      EntryCrudService.update(entryTableFor['drink']!, id, {
        'amount_ml': amountMl,
        'notes': notes,
      });

  void reset() {
    state = const EntriesState();
  }
}

final entriesProvider =
    NotifierProvider<EntriesNotifier, EntriesState>(EntriesNotifier.new);
