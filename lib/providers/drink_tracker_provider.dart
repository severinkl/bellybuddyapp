import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/drink.dart';
import '../models/drink_entry.dart';
import '../services/drink_service.dart';
import '../services/supabase_service.dart';
import '../utils/drink_helpers.dart';
import '../utils/logger.dart';
import 'entries_provider.dart';

class DrinkTrackerState {
  final List<Drink> allDrinks;
  final List<Drink> quickDrinks;
  final List<Drink> suggestions;
  final Drink? selectedDrink;
  final int? selectedAmount;
  final String customAmount;
  final bool isLoading;
  final bool isSaving;
  final bool showSuccess;
  final int todayTotal;
  final DateTime trackedAt;

  DrinkTrackerState({
    this.allDrinks = const [],
    this.quickDrinks = const [],
    this.suggestions = const [],
    this.selectedDrink,
    this.selectedAmount,
    this.customAmount = '',
    this.isLoading = true,
    this.isSaving = false,
    this.showSuccess = false,
    this.todayTotal = 0,
    DateTime? trackedAt,
  }) : trackedAt = trackedAt ?? DateTime.now();

  static const _unset = Object();

  DrinkTrackerState copyWith({
    List<Drink>? allDrinks,
    List<Drink>? quickDrinks,
    List<Drink>? suggestions,
    Object? selectedDrink = _unset,
    Object? selectedAmount = _unset,
    String? customAmount,
    bool? isLoading,
    bool? isSaving,
    bool? showSuccess,
    int? todayTotal,
    DateTime? trackedAt,
  }) {
    return DrinkTrackerState(
      allDrinks: allDrinks ?? this.allDrinks,
      quickDrinks: quickDrinks ?? this.quickDrinks,
      suggestions: suggestions ?? this.suggestions,
      selectedDrink: identical(selectedDrink, _unset)
          ? this.selectedDrink
          : selectedDrink as Drink?,
      selectedAmount: identical(selectedAmount, _unset)
          ? this.selectedAmount
          : selectedAmount as int?,
      customAmount: customAmount ?? this.customAmount,
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

      // Build quick drinks from recent entries
      final userId = SupabaseService.userId;
      List<Drink> quick;
      if (userId != null) {
        final recentIds = await DrinkService.fetchRecentDrinkIds(userId);
        quick = DrinkHelpers.buildQuickDrinks(drinks, recentIds);
      } else {
        quick = drinks.take(11).toList();
      }

      state = state.copyWith(
        allDrinks: drinks,
        quickDrinks: quick,
        isLoading: false,
      );
    } catch (e, st) {
      _log.error('failed to load drinks', e, st);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadTodayTotal() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        _log.debug('loadTodayTotal: no user');
        return;
      }
      final total = await DrinkService.fetchTodayTotal(userId);
      state = state.copyWith(todayTotal: total);
    } catch (e, st) {
      _log.error('failed to load today total', e, st);
    }
  }

  void searchDrinks(String query) {
    final results = DrinkHelpers.search(query, state.allDrinks);
    state = state.copyWith(suggestions: results);
  }

  void toggleDrink(Drink drink) {
    if (state.selectedDrink?.id == drink.id) {
      state = state.copyWith(
        selectedDrink: null,
        selectedAmount: null,
        customAmount: '',
        suggestions: [],
      );
    } else {
      state = state.copyWith(selectedDrink: drink, suggestions: []);
    }
  }

  void clearSelection() {
    state = state.copyWith(
      selectedDrink: null,
      selectedAmount: null,
      customAmount: '',
    );
  }

  void selectAmount(int amount) {
    state = state.copyWith(selectedAmount: amount, customAmount: '');
  }

  void setCustomAmount(String value) {
    state = state.copyWith(
      customAmount: value,
      selectedAmount: DrinkHelpers.parseAmount(value),
    );
  }

  void setTrackedAt(DateTime dt) {
    state = state.copyWith(trackedAt: dt);
  }

  Future<void> createDrink(String name) async {
    final newDrink = await DrinkService.insertDrink(name);
    final updatedAll = [...state.allDrinks, newDrink]
      ..sort((a, b) => a.name.compareTo(b.name));
    state = state.copyWith(
      allDrinks: updatedAll,
      quickDrinks: [newDrink, ...state.quickDrinks],
      selectedDrink: newDrink,
      suggestions: [],
    );
  }

  Future<void> deleteDrink(Drink drink) async {
    try {
      await DrinkService.deleteDrink(drink.id);
      final updatedAll = state.allDrinks
          .where((d) => d.id != drink.id)
          .toList();
      final updatedQuick = state.quickDrinks
          .where((d) => d.id != drink.id)
          .toList();
      final updatedSuggestions = state.suggestions
          .where((d) => d.id != drink.id)
          .toList();
      state = state.copyWith(
        allDrinks: updatedAll,
        quickDrinks: updatedQuick,
        suggestions: updatedSuggestions,
      );
      if (state.selectedDrink?.id == drink.id) {
        clearSelection();
      }
    } catch (e, st) {
      _log.error('failed to delete drink', e, st);
      rethrow;
    }
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
      await loadTodayTotal();
      state = state.copyWith(isSaving: false, showSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

final drinkTrackerProvider =
    NotifierProvider<DrinkTrackerNotifier, DrinkTrackerState>(
      DrinkTrackerNotifier.new,
    );
