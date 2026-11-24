import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../providers/buddy_provider.dart';
import '../providers/core_providers.dart';
import '../repositories/entry_repository.dart';
import '../services/entry_query_service.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

/// The entries of one local day ([day]); the dashboard's ring and „Heute"
/// list show them.
class EntriesState {
  final List<MealEntry> meals;
  final List<ToiletEntry> toiletEntries;
  final List<GutFeelingEntry> gutFeelings;
  final List<DrinkEntry> drinks;
  final bool isLoading;
  final Object? error;

  /// The latest meal, drink and Bauchgefühl before [day]; the Buddy's
  /// meters reach back over midnight with them.
  final LatestEntries latestBefore;

  /// The local day (its midnight) loaded last, set as its load starts;
  /// null until the first load.
  final DateTime? day;

  const EntriesState({
    this.meals = const [],
    this.toiletEntries = const [],
    this.gutFeelings = const [],
    this.drinks = const [],
    this.isLoading = false,
    this.error,
    this.latestBefore = const LatestEntries(),
    this.day,
  });

  EntriesState copyWith({
    List<MealEntry>? meals,
    List<ToiletEntry>? toiletEntries,
    List<GutFeelingEntry>? gutFeelings,
    List<DrinkEntry>? drinks,
    bool? isLoading,
    Object? error,
    LatestEntries? latestBefore,
    DateTime? day,
  }) {
    return EntriesState(
      meals: meals ?? this.meals,
      toiletEntries: toiletEntries ?? this.toiletEntries,
      gutFeelings: gutFeelings ?? this.gutFeelings,
      drinks: drinks ?? this.drinks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      latestBefore: latestBefore ?? this.latestBefore,
      day: day ?? this.day,
    );
  }
}

/// The entries of one day. Every write through it reloads that day, so the
/// state stays current whoever wrote (a tracker, the diary), and raises
/// [entriesRevisionProvider].
class EntriesNotifier extends Notifier<EntriesState> {
  static const _log = AppLogger('EntriesNotifier');

  /// Counts loads (and resets); only the latest load publishes its result.
  int _load = 0;

  @override
  EntriesState build() {
    _load++;
    return const EntriesState();
  }

  /// Loads the entries of [date]'s local day ([EntriesState.day]). A load
  /// started meanwhile supersedes this one.
  Future<void> loadEntries(DateTime date) async {
    final load = ++_load;
    state = state.copyWith(isLoading: true, error: null, day: startOfDay(date));
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _log.debug('loadEntries: no user');
        return;
      }

      final repo = ref.read(entryRepositoryProvider);
      // Both start now. The day's error is the load's error, so the pair is
      // not awaited as one ((a, b).wait would wrap it).
      final dayFuture = repo.fetchForDate(
        userId: userId,
        date: date,
        ordered: true,
      );
      final latestFuture = _fetchLatestBefore(repo, userId, startOfDay(date));
      final result = await dayFuture;
      final latestBefore = await latestFuture;
      if (!_isLatest(load)) return;

      state = state.copyWith(
        meals: result.meals,
        toiletEntries: result.toiletEntries,
        gutFeelings: result.gutFeelings,
        drinks: result.drinks,
        latestBefore: latestBefore,
        isLoading: false,
      );
    } catch (e, st) {
      _log.error('loadEntries failed for $date', e, st);
      if (_isLatest(load)) state = state.copyWith(isLoading: false, error: e);
      rethrow;
    }
  }

  /// The latest entries before [before]; a failing query is logged and
  /// gives none, so the day itself still loads.
  Future<LatestEntries> _fetchLatestBefore(
    EntryRepository repo,
    String userId,
    DateTime before,
  ) async {
    try {
      return await repo.fetchLatestBefore(userId: userId, before: before);
    } catch (e, st) {
      _log.error('fetchLatestBefore failed before $before', e, st);
      return const LatestEntries();
    }
  }

  bool _isLatest(int load) => ref.mounted && load == _load;

  /// Runs [write], announces it ([entriesRevisionProvider]), then reloads
  /// the loaded day in the background so the state shows it. Before the
  /// first load there is nothing to reload.
  ///
  /// With [refreshesBuddy] (an edit, a move or a delete) a loaded Buddy
  /// reloads too: the write can change his streak or whether today counts
  /// (today's only entry deleted). An insert needs none of it; a tracker's
  /// log event already refreshes him.
  Future<void> _write(
    Future<void> Function() write, {
    bool refreshesBuddy = false,
  }) async {
    await write();
    if (!ref.mounted) return;
    ref.read(entriesRevisionProvider.notifier)._bump();
    if (refreshesBuddy && ref.read(buddyProvider.exists)) {
      unawaited(ref.read(buddyProvider.notifier).reload());
    }
    final day = state.day;
    // A failing reload is logged by loadEntries; the write itself is done.
    if (day != null) loadEntries(day).ignore();
  }

  EntryRepository get _repo => ref.read(entryRepositoryProvider);

  Future<void> _insert(String type, Map<String, dynamic> data) {
    final userId = ref.read(currentUserIdProvider)!;
    return _write(
      () => _repo.insertEntry(entryTableFor[type]!, data, userId: userId),
    );
  }

  Future<void> _update(String type, String id, Map<String, dynamic> data) =>
      _write(
        () => _repo.updateEntry(entryTableFor[type]!, id, data),
        refreshesBuddy: true,
      );

  Future<void> _delete(String type, String id) => _write(
    () => _repo.deleteEntry(entryTableFor[type]!, id),
    refreshesBuddy: true,
  );

  // -- Meal CRUD --

  Future<void> addMeal(MealEntry meal) => _insert('meal', meal.toJson());

  Future<void> updateMeal(MealEntry meal) =>
      _update('meal', meal.id, meal.toJson());

  Future<void> deleteMeal(String id) => _delete('meal', id);

  // -- Toilet CRUD --

  Future<void> addToiletEntry(ToiletEntry entry) =>
      _insert('toilet', entry.toJson());

  Future<void> updateToiletEntry(ToiletEntry entry) =>
      _update('toilet', entry.id, entry.toJson());

  Future<void> deleteToiletEntry(String id) => _delete('toilet', id);

  // -- Gut feeling CRUD --

  Future<void> addGutFeeling(GutFeelingEntry entry) =>
      _insert('gutFeeling', entry.toJson());

  Future<void> updateGutFeeling(GutFeelingEntry entry) =>
      _update('gutFeeling', entry.id, entry.toJson());

  Future<void> deleteGutFeeling(String id) => _delete('gutFeeling', id);

  // -- Drink CRUD --

  Future<void> addDrinkEntry(DrinkEntry entry) =>
      _insert('drink', entry.toInsertJson());

  Future<void> updateDrinkEntry(DrinkEntry entry) =>
      _update('drink', entry.id, entry.toInsertJson());

  Future<void> deleteDrinkEntry(String id) => _delete('drink', id);

  // -- Generic delete by type (used by diary) --

  Future<void> deleteByType(String type, String id) =>
      _write(() => _repo.deleteByType(type, id), refreshesBuddy: true);

  // -- Typed update by ID (used by diary detail sheets) --
  // A non-null [trackedAt] moves the entry to that date and time.

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
    DateTime? trackedAt,
  }) => _update('gutFeeling', id, {
    'bloating': bloating,
    'gas': gas,
    'cramps': cramps,
    'fullness': fullness,
    'stress': stress,
    'happiness': happiness,
    'energy': energy,
    'focus': focus,
    'body_feel': bodyFeel,
    ..._trackedAtJson(trackedAt),
  });

  Future<void> updateToiletById(
    String id, {
    required int stoolType,
    DateTime? trackedAt,
  }) => _update('toilet', id, {
    'stool_type': stoolType,
    ..._trackedAtJson(trackedAt),
  });

  Future<void> updateDrinkById(
    String id, {
    required int amountMl,
    String? notes,
    DateTime? trackedAt,
  }) => _update('drink', id, {
    'amount_ml': amountMl,
    'notes': notes,
    ..._trackedAtJson(trackedAt),
  });

  /// `tracked_at` as the entry models write it, or nothing for null.
  static Map<String, dynamic> _trackedAtJson(DateTime? trackedAt) => {
    if (trackedAt != null) 'tracked_at': trackedAt.toIso8601String(),
  };

  void reset() {
    _load++;
    state = const EntriesState();
  }
}

final entriesProvider = NotifierProvider<EntriesNotifier, EntriesState>(
  EntriesNotifier.new,
);

/// The entry-write signal: rises by one after every entry write that went
/// through [EntriesNotifier] (insert, update, delete of any kind: a
/// tracker's log, a meal edit or moved date, a diary edit or delete), once
/// the write is done. A failed write leaves it alone; loads never change it.
///
/// Whatever is computed from the user's entries beyond the day
/// [entriesProvider] holds (the insights) listens to it to recompute after
/// any write, whoever made it:
///
/// ```dart
/// ref.listen(entriesRevisionProvider, (_, _) => unawaited(refresh()));
/// ```
///
/// Only the value's change means something; it starts at 0 each session.
final entriesRevisionProvider = NotifierProvider<EntriesRevision, int>(
  EntriesRevision.new,
);

/// The count behind [entriesRevisionProvider]; only [EntriesNotifier]
/// raises it.
class EntriesRevision extends Notifier<int> {
  @override
  int build() => 0;

  void _bump() => state++;
}
