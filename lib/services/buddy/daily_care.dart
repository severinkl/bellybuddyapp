import 'dart:math' as math;

import '../../providers/entries_provider.dart';
import '../../utils/date_format_utils.dart';

/// The Buddy's four daily needs, one per tracker; they make up the
/// dashboard's care ring.
enum CareNeed {
  food('🍽', 'Essen'),
  drink('💧', 'Trinken'),
  gutFeeling('🙂', 'Bauchgefühl'),
  toilet('🧻', 'Klo');

  const CareNeed(this.emoji, this.label);

  /// Its icon in the care ring and the „Heute" list.
  final String emoji;

  /// Its name in the care ring.
  final String label;

  /// Logging it, as an action („Trinken eintragen").
  String get logLabel => '$label eintragen';
}

/// What the dashboard suggests logging next ([nextCareAction]).
enum CareAction {
  breakfast(CareNeed.food),
  lunch(CareNeed.food),
  snack(CareNeed.food),
  dinner(CareNeed.food),
  drink(CareNeed.drink),
  gutFeeling(CareNeed.gutFeeling),

  /// Nothing open right now: the plain „Essen eintragen" shortcut.
  feed(null);

  const CareAction(this.need);

  /// The need this action fills; null for [feed].
  final CareNeed? need;
}

/// How many glasses [ml] millilitres of drinks are: [DailyCare.mlPerGlass]
/// per glass, rounded; any drink counts as at least one glass.
int glassesForMl(int ml) =>
    ml <= 0 ? 0 : math.max(1, (ml / DailyCare.mlPerGlass).round());

/// What the user logged today, per need (local day).
class DailyCare {
  const DailyCare({
    this.meals = 0,
    this.drinks = 0,
    this.glasses = 0,
    this.gutFeelings = 0,
    this.toilets = 0,
    this.lastMealAt,
    this.lastLogAt,
  });

  static const mealGoal = 3;
  static const glassGoal = 6;
  static const gutFeelingGoal = 1;
  static const mlPerGlass = 250;

  final int meals;

  /// Today's drink entries, whatever their volume.
  final int drinks;

  /// Today's drinks in glasses ([glassesForMl] of their total volume).
  final int glasses;
  final int gutFeelings;
  final int toilets;

  /// Local time of today's latest meal.
  final DateTime? lastMealAt;

  /// Local time of today's latest entry of any kind.
  final DateTime? lastLogAt;

  /// All of today's entries.
  int get entries => meals + drinks + gutFeelings + toilets;

  /// How many of the four kinds (meal, drink, Bauchgefühl, Klo) have an
  /// entry today.
  int get kindsLogged =>
      [meals, drinks, gutFeelings, toilets].where((n) => n > 0).length;

  factory DailyCare.fromEntries(EntriesState s, DateTime now) {
    /// The local times of today's entries among [trackedAt].
    List<DateTime> today(Iterable<DateTime> trackedAt) => [
      for (final t in trackedAt)
        if (isSameDay(t.toLocal(), now)) t.toLocal(),
    ];
    DateTime? latest(List<DateTime> times) =>
        times.isEmpty ? null : times.reduce((a, b) => a.isAfter(b) ? a : b);

    final drinks = [
      for (final d in s.drinks)
        if (isSameDay(d.trackedAt.toLocal(), now)) d,
    ];
    final mealTimes = today(s.meals.map((e) => e.trackedAt));
    final gutFeelingTimes = today(s.gutFeelings.map((e) => e.trackedAt));
    final toiletTimes = today(s.toiletEntries.map((e) => e.trackedAt));
    return DailyCare(
      meals: mealTimes.length,
      drinks: drinks.length,
      glasses: glassesForMl(drinks.fold(0, (sum, d) => sum + d.amountMl)),
      gutFeelings: gutFeelingTimes.length,
      toilets: toiletTimes.length,
      lastMealAt: latest(mealTimes),
      lastLogAt: latest([
        ...mealTimes,
        for (final d in drinks) d.trackedAt.toLocal(),
        ...gutFeelingTimes,
        ...toiletTimes,
      ]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyCare &&
      other.meals == meals &&
      other.drinks == drinks &&
      other.glasses == glasses &&
      other.gutFeelings == gutFeelings &&
      other.toilets == toilets &&
      other.lastMealAt == lastMealAt &&
      other.lastLogAt == lastLogAt;

  @override
  int get hashCode => Object.hash(
    meals,
    drinks,
    glasses,
    gutFeelings,
    toilets,
    lastMealAt,
    lastLogAt,
  );

  /// The daily goal of [need]; null for Klo (counted, never a target).
  static int? goalFor(CareNeed need) => switch (need) {
    CareNeed.food => mealGoal,
    CareNeed.drink => glassGoal,
    CareNeed.gutFeeling => gutFeelingGoal,
    CareNeed.toilet => null,
  };

  int count(CareNeed need) => switch (need) {
    CareNeed.food => meals,
    CareNeed.drink => glasses,
    CareNeed.gutFeeling => gutFeelings,
    CareNeed.toilet => toilets,
  };

  /// 0..1; a need without a goal is full once logged.
  double progress(CareNeed need) {
    final goal = goalFor(need);
    final n = count(need);
    if (goal == null) return n > 0 ? 1 : 0;
    return math.min(1, n / goal);
  }

  bool isMet(CareNeed need) => progress(need) >= 1;
}

/// The Buddy's day: where its parts start, in minutes after local
/// midnight.
abstract final class DayParts {
  /// Mittagessen is asked for from here (Frühstück before), and a meal
  /// from here on counts for lunch and the afternoon snack.
  static const lunchFrom = 10 * 60 + 30;

  /// The afternoon snack.
  static const snackFrom = 15 * 60;

  /// Abendessen.
  static const dinnerFrom = 17 * 60;

  /// The dashboard Buddy's resting line names his next need by day, from
  /// [dayFrom] until [nightFrom]. Breakfast is asked for, and counted, from
  /// [dayFrom] on.
  static const dayFrom = 5 * 60;
  static const nightFrom = 22 * 60;

  /// [t]'s minutes after midnight.
  static int minuteOf(DateTime t) => t.hour * 60 + t.minute;

  /// Whether [t] is by day ([dayFrom] until [nightFrom]).
  static bool isDay(DateTime t) {
    final minute = minuteOf(t);
    return minute >= dayFrom && minute < nightFrom;
  }
}

/// The meal the time of day asks for: none before [DayParts.dayFrom],
/// Frühstück until [DayParts.lunchFrom], Mittagessen until
/// [DayParts.snackFrom], a snack until [DayParts.dinnerFrom], then
/// Abendessen.
CareAction? mealSlotAt(DateTime now) {
  final minute = DayParts.minuteOf(now);
  if (minute < DayParts.dayFrom) return null;
  if (minute < DayParts.lunchFrom) return CareAction.breakfast;
  if (minute < DayParts.snackFrom) return CareAction.lunch;
  if (minute < DayParts.dinnerFrom) return CareAction.snack;
  return CareAction.dinner;
}

/// Since when (minutes after midnight) a meal counts for each meal slot:
/// breakfast from [DayParts.dayFrom] (a late-night meal is none), lunch and
/// the afternoon snack from [DayParts.lunchFrom], dinner from
/// [DayParts.dinnerFrom].
const _mealCountsFrom = {
  CareAction.breakfast: DayParts.dayFrom,
  CareAction.lunch: DayParts.lunchFrom,
  CareAction.snack: DayParts.lunchFrom,
  CareAction.dinner: DayParts.dinnerFrom,
};

/// The next thing to log: the meal the time of day asks for (none at night
/// before [DayParts.dayFrom]) until a meal is logged in its slot (a skipped
/// breakfast is not asked for at noon), then Trinken under its goal, then
/// Bauchgefühl, else [CareAction.feed]. Klo never drives it.
CareAction nextCareAction(DailyCare care, DateTime now) {
  final slot = mealSlotAt(now);
  if (slot != null && care.meals < DailyCare.mealGoal) {
    final from = _mealCountsFrom[slot]!;
    final slotStart = DateTime(
      now.year,
      now.month,
      now.day,
      from ~/ 60,
      from % 60,
    );
    final last = care.lastMealAt;
    if (last == null || last.isBefore(slotStart)) return slot;
  }
  if (!care.isMet(CareNeed.drink)) return CareAction.drink;
  if (!care.isMet(CareNeed.gutFeeling)) return CareAction.gutFeeling;
  return CareAction.feed;
}
