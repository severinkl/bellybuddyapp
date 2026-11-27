import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/drink.dart';
import '../models/drink_entry.dart';
import '../providers/core_providers.dart';
import '../repositories/drink_repository.dart';
import '../utils/date_format_utils.dart';
import '../utils/drink_helpers.dart';
import '../utils/logger.dart';
import 'diary_provider.dart';
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

  /// The ml drunk on [trackedAt]'s day (without the drink being entered).
  final int dayTotal;

  /// The drink and amount of the user's latest entry; null without one.
  final LastDrink? lastDrink;

  /// The drink search is open.
  final bool isSearchOpen;
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
    this.dayTotal = 0,
    this.lastDrink,
    this.isSearchOpen = false,
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
    int? dayTotal,
    Object? lastDrink = _unset,
    bool? isSearchOpen,
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
      dayTotal: dayTotal ?? this.dayTotal,
      lastDrink: identical(lastDrink, _unset)
          ? this.lastDrink
          : lastDrink as LastDrink?,
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
      trackedAt: trackedAt ?? this.trackedAt,
    );
  }
}

class DrinkTrackerNotifier extends Notifier<DrinkTrackerState> {
  static const _log = AppLogger('DrinkTracker');
  @override
  DrinkTrackerState build() => DrinkTrackerState(trackedAt: DateTime.now());

  /// Reset to fresh state at [trackedAt] (default: now) — call when
  /// opening the tracker screen. The search is closed, without suggestions.
  void reset({DateTime? trackedAt}) =>
      state = DrinkTrackerState(trackedAt: trackedAt ?? DateTime.now());

  Future<void> loadDrinks() async {
    try {
      final drinkRepo = ref.read(drinkRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        // Signed out: no history, no last entry.
        final drinks = await drinkRepo.fetchAll();
        state = state.copyWith(
          allDrinks: drinks,
          quickDrinks: drinks.take(AppConstants.drinkFallbackCount).toList(),
          lastDrink: null,
          isLoading: false,
        );
        return;
      }
      final (drinks, recentIds, lastEntry) = await (
        drinkRepo.fetchAll(),
        _fetchRecentIds(drinkRepo, userId),
        _fetchLastEntry(drinkRepo, userId),
      ).wait;
      state = state.copyWith(
        allDrinks: drinks,
        quickDrinks: DrinkHelpers.buildQuickDrinks(drinks, recentIds),
        lastDrink: _resolveLast(lastEntry, drinks),
        isLoading: false,
      );
    } catch (e, st) {
      _log.error('failed to load drinks', e, st);
      state = state.copyWith(isLoading: false);
    }
  }

  /// [entry]'s drink in [drinks] and its amount; null without an entry, for
  /// an unknown drink or an amount the form would refuse.
  static LastDrink? _resolveLast(DrinkEntry? entry, List<Drink> drinks) {
    if (entry == null || !DrinkHelpers.isValidAmount(entry.amountMl)) {
      return null;
    }
    final drink = drinks.where((d) => d.id == entry.drinkId).firstOrNull;
    return drink == null ? null : (drink: drink, amountMl: entry.amountMl);
  }

  /// The ids of recently drunk drinks; empty when the fetch fails (the
  /// catalogue and the starter tiles still show).
  Future<List<String>> _fetchRecentIds(
    DrinkRepository repo,
    String userId,
  ) async {
    try {
      return await repo.fetchRecentDrinkIds(userId);
    } catch (e, st) {
      _log.error('failed to load recent drinks', e, st);
      return const [];
    }
  }

  /// The latest entry; null when there is none or the fetch fails (the rest
  /// of the screen loads without the one-tap row).
  Future<DrinkEntry?> _fetchLastEntry(
    DrinkRepository repo,
    String userId,
  ) async {
    try {
      return await repo.fetchLastEntry(userId);
    } catch (e, st) {
      _log.error('failed to load the last drink', e, st);
      return null;
    }
  }

  /// Loads [DrinkTrackerState.dayTotal] for [DrinkTrackerState.trackedAt]'s
  /// day. A result for a day the entry has since moved away from is dropped.
  Future<void> loadDayTotal() async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('loadDayTotal: no user');
        return;
      }
      final day = startOfDay(state.trackedAt);
      final total = await ref
          .read(drinkRepositoryProvider)
          .fetchDayTotal(userId, day);
      if (!ref.mounted || startOfDay(state.trackedAt) != day) return;
      state = state.copyWith(dayTotal: total);
    } catch (e, st) {
      _log.error('failed to load the day total', e, st);
    }
  }

  void searchDrinks(String query) {
    final results = DrinkHelpers.search(query, state.allDrinks);
    state = state.copyWith(suggestions: results);
  }

  void openSearch() => state = state.copyWith(isSearchOpen: true);

  void closeSearch() =>
      state = state.copyWith(isSearchOpen: false, suggestions: []);

  void toggleDrink(Drink drink) {
    if (state.selectedDrink?.id == drink.id) {
      state = state.copyWith(
        selectedDrink: null,
        selectedAmount: null,
        customAmount: '',
        suggestions: [],
        isSearchOpen: false,
      );
    } else {
      state = state.copyWith(
        selectedDrink: drink,
        suggestions: [],
        isSearchOpen: false,
      );
    }
  }

  /// Selects [drink] as picked in the search, which closes: never
  /// deselects, and the chosen amount stays.
  void selectDrink(Drink drink) {
    state = state.copyWith(
      selectedDrink: drink,
      suggestions: [],
      isSearchOpen: false,
    );
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

  /// Sets the entry's time; another day loads that day's total.
  void setTrackedAt(DateTime dt) {
    final dayChanged = !isSameDay(dt, state.trackedAt);
    state = state.copyWith(trackedAt: dt);
    if (dayChanged) loadDayTotal();
  }

  Future<void> createDrink(String name) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final newDrink = await ref
        .read(drinkRepositoryProvider)
        .insertDrink(name, userId: userId);
    final updatedAll = [...state.allDrinks, newDrink]
      ..sort((a, b) => a.name.compareTo(b.name));
    state = state.copyWith(
      allDrinks: updatedAll,
      selectedDrink: newDrink,
      suggestions: [],
      isSearchOpen: false,
    );
  }

  Future<void> deleteDrink(Drink drink) async {
    try {
      await ref.read(drinkRepositoryProvider).deleteDrink(drink.id);
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
    // The delete took the drink's entries with it: the day total may have
    // changed, and the last entry if it was this drink's.
    final wasLast = state.lastDrink?.drink.id == drink.id;
    if (wasLast) state = state.copyWith(lastDrink: null);
    await Future.wait([if (wasLast) _reloadLast(), loadDayTotal()]);
  }

  /// Re-fetches the last entry and resolves it against the loaded drinks.
  Future<void> _reloadLast() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final entry = await _fetchLastEntry(
      ref.read(drinkRepositoryProvider),
      userId,
    );
    if (!ref.mounted) return;
    state = state.copyWith(lastDrink: _resolveLast(entry, state.allDrinks));
  }

  /// Stores the last drink and its amount at [DrinkTrackerState.trackedAt];
  /// the selection stays untouched.
  Future<void> saveLast() async {
    final last = state.lastDrink;
    if (last == null) return;
    await _store(last.drink, last.amountMl);
  }

  Future<void> save() async {
    final drink = state.selectedDrink;
    final amount = state.selectedAmount;
    if (drink == null || amount == null) return;
    await _store(drink, amount);
  }

  Future<void> _store(Drink drink, int amountMl) async {
    state = state.copyWith(isSaving: true);
    try {
      final entry = DrinkEntry(
        id: const Uuid().v4(),
        trackedAt: state.trackedAt,
        drinkId: drink.id,
        drinkName: drink.name,
        amountMl: amountMl,
      );
      await ref.read(entriesProvider.notifier).addDrinkEntry(entry);
      await loadDayTotal();

      // Invalidate diary cache so it refetches with the new entry
      final date = DateTime(
        state.trackedAt.year,
        state.trackedAt.month,
        state.trackedAt.day,
      );
      ref.invalidate(diaryEntriesProvider(date));

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
