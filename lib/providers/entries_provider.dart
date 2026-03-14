import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../services/entry_query_service.dart';
import '../services/supabase_service.dart';

/// Table name for each entry type
const _tableFor = {
  'meal': 'meal_entries',
  'toilet': 'toilet_entries',
  'gutFeeling': 'gut_feeling_entries',
  'drink': 'drink_entries',
};

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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
      rethrow;
    }
  }

  // -- Private CRUD helpers --

  Future<void> _insertEntry(String table, Map<String, dynamic> data) async {
    data['user_id'] = SupabaseService.userId;
    data.remove('id');
    data.remove('created_at');
    await SupabaseService.client.from(table).insert(data);
  }

  Future<void> _updateEntry(String table, String id, Map<String, dynamic> data) async {
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at');
    await SupabaseService.client.from(table).update(data).eq('id', id);
  }

  Future<void> _deleteEntry(String table, String id) async {
    await SupabaseService.client.from(table).delete().eq('id', id);
  }

  // -- Meal CRUD --

  Future<void> addMeal(MealEntry meal) =>
      _insertEntry(_tableFor['meal']!, meal.toJson());

  Future<void> updateMeal(MealEntry meal) =>
      _updateEntry(_tableFor['meal']!, meal.id, meal.toJson());

  Future<void> deleteMeal(String id) =>
      _deleteEntry(_tableFor['meal']!, id);

  // -- Toilet CRUD --

  Future<void> addToiletEntry(ToiletEntry entry) =>
      _insertEntry(_tableFor['toilet']!, entry.toJson());

  Future<void> updateToiletEntry(ToiletEntry entry) =>
      _updateEntry(_tableFor['toilet']!, entry.id, entry.toJson());

  Future<void> deleteToiletEntry(String id) =>
      _deleteEntry(_tableFor['toilet']!, id);

  // -- Gut feeling CRUD --

  Future<void> addGutFeeling(GutFeelingEntry entry) =>
      _insertEntry(_tableFor['gutFeeling']!, entry.toJson());

  Future<void> updateGutFeeling(GutFeelingEntry entry) =>
      _updateEntry(_tableFor['gutFeeling']!, entry.id, entry.toJson());

  Future<void> deleteGutFeeling(String id) =>
      _deleteEntry(_tableFor['gutFeeling']!, id);

  // -- Drink CRUD --

  /// Inserts a drink entry using a manually constructed map instead of
  /// [DrinkEntry.toJson] because `drinkName` is excluded from JSON
  /// serialization (it comes from a join, not the `drink_entries` table).
  Future<void> addDrinkEntry(DrinkEntry entry) async {
    final data = {
      'user_id': SupabaseService.userId,
      'tracked_at': entry.trackedAt.toIso8601String(),
      'drink_id': entry.drinkId,
      'amount_ml': entry.amountMl,
      'notes': entry.notes,
    };
    await SupabaseService.client.from(_tableFor['drink']!).insert(data);
  }

  Future<void> updateDrinkEntry(DrinkEntry entry) async {
    final data = {
      'tracked_at': entry.trackedAt.toIso8601String(),
      'drink_id': entry.drinkId,
      'amount_ml': entry.amountMl,
      'notes': entry.notes,
    };
    await SupabaseService.client.from(_tableFor['drink']!).update(data).eq('id', entry.id);
  }

  Future<void> deleteDrinkEntry(String id) =>
      _deleteEntry(_tableFor['drink']!, id);

  // -- Generic delete by type (used by diary) --

  Future<void> deleteByType(String type, String id) async {
    final table = switch (type) {
      'meal' => _tableFor['meal']!,
      'toilet' => _tableFor['toilet']!,
      'gutFeeling' => _tableFor['gutFeeling']!,
      'drink' => _tableFor['drink']!,
      _ => throw ArgumentError('Unknown entry type: $type'),
    };
    await _deleteEntry(table, id);
  }

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
      _updateEntry(_tableFor['gutFeeling']!, id, {
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
      _updateEntry(_tableFor['toilet']!, id, {
        'stool_type': stoolType,
      });

  Future<void> updateDrinkById(
    String id, {
    required int amountMl,
    String? notes,
  }) =>
      _updateEntry(_tableFor['drink']!, id, {
        'amount_ml': amountMl,
        'notes': notes,
      });

  void reset() {
    state = const EntriesState();
  }
}

final entriesProvider =
    NotifierProvider<EntriesNotifier, EntriesState>(EntriesNotifier.new);
