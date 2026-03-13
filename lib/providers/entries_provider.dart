import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../services/supabase_service.dart';

/// State holding all entries for a given date range
class EntriesState {
  final List<MealEntry> meals;
  final List<ToiletEntry> toiletEntries;
  final List<GutFeelingEntry> gutFeelings;
  final List<DrinkEntry> drinks;
  final bool isLoading;

  const EntriesState({
    this.meals = const [],
    this.toiletEntries = const [],
    this.gutFeelings = const [],
    this.drinks = const [],
    this.isLoading = false,
  });

  EntriesState copyWith({
    List<MealEntry>? meals,
    List<ToiletEntry>? toiletEntries,
    List<GutFeelingEntry>? gutFeelings,
    List<DrinkEntry>? drinks,
    bool? isLoading,
  }) {
    return EntriesState(
      meals: meals ?? this.meals,
      toiletEntries: toiletEntries ?? this.toiletEntries,
      gutFeelings: gutFeelings ?? this.gutFeelings,
      drinks: drinks ?? this.drinks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class EntriesNotifier extends StateNotifier<EntriesState> {
  EntriesNotifier() : super(const EntriesState());

  Future<void> loadEntries(DateTime date) async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final start = startOfDay.toIso8601String();
      final end = endOfDay.toIso8601String();

      final results = await Future.wait([
        SupabaseService.client
            .from('meal_entries')
            .select()
            .eq('user_id', userId)
            .gte('tracked_at', start)
            .lt('tracked_at', end)
            .order('tracked_at', ascending: false),
        SupabaseService.client
            .from('toilet_entries')
            .select()
            .eq('user_id', userId)
            .gte('tracked_at', start)
            .lt('tracked_at', end)
            .order('tracked_at', ascending: false),
        SupabaseService.client
            .from('gut_feeling_entries')
            .select()
            .eq('user_id', userId)
            .gte('tracked_at', start)
            .lt('tracked_at', end)
            .order('tracked_at', ascending: false),
        SupabaseService.client
            .from('drink_entries')
            .select('*, drinks(name)')
            .eq('user_id', userId)
            .gte('tracked_at', start)
            .lt('tracked_at', end)
            .order('tracked_at', ascending: false),
      ]);

      state = state.copyWith(
        meals: (results[0] as List).map((e) => MealEntry.fromJson(e)).toList(),
        toiletEntries: (results[1] as List).map((e) => ToiletEntry.fromJson(e)).toList(),
        gutFeelings: (results[2] as List).map((e) => GutFeelingEntry.fromJson(e)).toList(),
        drinks: (results[3] as List).map((e) => DrinkEntry.fromDbRow(e)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // Meal CRUD
  Future<void> addMeal(MealEntry meal) async {
    final data = meal.toJson();
    data['user_id'] = SupabaseService.userId;
    data.remove('id');
    data.remove('created_at');
    await SupabaseService.client.from('meal_entries').insert(data);
  }

  Future<void> updateMeal(MealEntry meal) async {
    final data = meal.toJson();
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at');
    await SupabaseService.client.from('meal_entries').update(data).eq('id', meal.id);
  }

  Future<void> deleteMeal(String id) async {
    await SupabaseService.client.from('meal_entries').delete().eq('id', id);
  }

  // Toilet CRUD
  Future<void> addToiletEntry(ToiletEntry entry) async {
    final data = entry.toJson();
    data['user_id'] = SupabaseService.userId;
    data.remove('id');
    data.remove('created_at');
    await SupabaseService.client.from('toilet_entries').insert(data);
  }

  Future<void> updateToiletEntry(ToiletEntry entry) async {
    final data = entry.toJson();
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at');
    await SupabaseService.client.from('toilet_entries').update(data).eq('id', entry.id);
  }

  Future<void> deleteToiletEntry(String id) async {
    await SupabaseService.client.from('toilet_entries').delete().eq('id', id);
  }

  // Gut feeling CRUD
  Future<void> addGutFeeling(GutFeelingEntry entry) async {
    final data = entry.toJson();
    data['user_id'] = SupabaseService.userId;
    data.remove('id');
    data.remove('created_at');
    await SupabaseService.client.from('gut_feeling_entries').insert(data);
  }

  Future<void> updateGutFeeling(GutFeelingEntry entry) async {
    final data = entry.toJson();
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at');
    await SupabaseService.client.from('gut_feeling_entries').update(data).eq('id', entry.id);
  }

  Future<void> deleteGutFeeling(String id) async {
    await SupabaseService.client.from('gut_feeling_entries').delete().eq('id', id);
  }

  // Drink CRUD
  Future<void> addDrinkEntry(DrinkEntry entry) async {
    final data = {
      'user_id': SupabaseService.userId,
      'tracked_at': entry.trackedAt.toIso8601String(),
      'drink_id': entry.drinkId,
      'amount_ml': entry.amountMl,
      'notes': entry.notes,
    };
    await SupabaseService.client.from('drink_entries').insert(data);
  }

  Future<void> updateDrinkEntry(DrinkEntry entry) async {
    final data = {
      'tracked_at': entry.trackedAt.toIso8601String(),
      'drink_id': entry.drinkId,
      'amount_ml': entry.amountMl,
      'notes': entry.notes,
    };
    await SupabaseService.client.from('drink_entries').update(data).eq('id', entry.id);
  }

  Future<void> deleteDrinkEntry(String id) async {
    await SupabaseService.client.from('drink_entries').delete().eq('id', id);
  }

  void reset() {
    state = const EntriesState();
  }
}

final entriesProvider =
    StateNotifierProvider<EntriesNotifier, EntriesState>((ref) {
  return EntriesNotifier();
});
