import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/drink.dart';
import '../models/drink_entry.dart';
import '../services/drink_service.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import 'entries_provider.dart';

class DrinkTrackerState {
  final List<Drink> allDrinks;
  final List<Drink> filteredDrinks;
  final Drink? selectedDrink;
  final int? selectedAmount;
  final bool isLoading;
  final bool isSaving;
  final bool showSuccess;
  final int todayTotal;
  final DateTime trackedAt;

  DrinkTrackerState({
    this.allDrinks = const [],
    this.filteredDrinks = const [],
    this.selectedDrink,
    this.selectedAmount,
    this.isLoading = true,
    this.isSaving = false,
    this.showSuccess = false,
    this.todayTotal = 0,
    DateTime? trackedAt,
  }) : trackedAt = trackedAt ?? DateTime.now();

  DrinkTrackerState copyWith({
    List<Drink>? allDrinks,
    List<Drink>? filteredDrinks,
    Drink? selectedDrink,
    int? selectedAmount,
    bool? isLoading,
    bool? isSaving,
    bool? showSuccess,
    int? todayTotal,
    DateTime? trackedAt,
  }) {
    return DrinkTrackerState(
      allDrinks: allDrinks ?? this.allDrinks,
      filteredDrinks: filteredDrinks ?? this.filteredDrinks,
      selectedDrink: selectedDrink ?? this.selectedDrink,
      selectedAmount: selectedAmount ?? this.selectedAmount,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      showSuccess: showSuccess ?? this.showSuccess,
      todayTotal: todayTotal ?? this.todayTotal,
      trackedAt: trackedAt ?? this.trackedAt,
    );
  }
}

class DrinkTrackerNotifier extends Notifier<DrinkTrackerState> {
  static const _log = AppLogger('DrinkTracker');
  @override
  DrinkTrackerState build() => DrinkTrackerState(trackedAt: DateTime.now());

  Future<void> loadDrinks() async {
    try {
      final drinks = await DrinkService.fetchAll();
      state = state.copyWith(
        allDrinks: drinks,
        filteredDrinks: drinks,
        isLoading: false,
      );
    } catch (e) {
      _log.error('failed to load drinks', e);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadTodayTotal() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return;
      final total = await DrinkService.fetchTodayTotal(userId);
      state = state.copyWith(todayTotal: total);
    } catch (e) {
      _log.error('failed to load today total', e);
    }
  }

  void filterDrinks(String query) {
    if (query.isEmpty) {
      state = state.copyWith(filteredDrinks: state.allDrinks);
      return;
    }
    final words = query.toLowerCase().split(' ');
    final filtered = state.allDrinks.where((d) {
      final name = d.name.toLowerCase();
      return words.every((w) => name.contains(w));
    }).toList()
      ..sort((a, b) {
        final aStarts = a.name.toLowerCase().startsWith(query.toLowerCase());
        final bStarts = b.name.toLowerCase().startsWith(query.toLowerCase());
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return a.name.compareTo(b.name);
      });
    state = state.copyWith(filteredDrinks: filtered);
  }

  void selectDrink(Drink drink) {
    state = state.copyWith(selectedDrink: drink);
  }

  void selectAmount(int amount) {
    state = state.copyWith(selectedAmount: amount);
  }

  void setTrackedAt(DateTime dt) {
    state = state.copyWith(trackedAt: dt);
  }

  Future<void> save() async {
    if (state.selectedDrink == null || state.selectedAmount == null) return;
    state = state.copyWith(isSaving: true);
    try {
      final entry = DrinkEntry(
        id: const Uuid().v4(),
        trackedAt: state.trackedAt,
        drinkId: state.selectedDrink!.id,
        drinkName: state.selectedDrink!.name,
        amountMl: state.selectedAmount!,
      );
      await ref.read(entriesProvider.notifier).addDrinkEntry(entry);
      state = state.copyWith(isSaving: false, showSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final drinkTrackerProvider =
    NotifierProvider<DrinkTrackerNotifier, DrinkTrackerState>(
        DrinkTrackerNotifier.new);
