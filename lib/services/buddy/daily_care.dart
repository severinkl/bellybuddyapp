import 'dart:math' as math;

import '../../providers/entries_provider.dart';

/// The Buddy's four daily needs, one per tracker; they make up the
/// dashboard's care ring.
enum CareNeed { food, drink, gutFeeling, toilet }

/// The meal the time of day asks for.
enum MealSlot { breakfast, lunch, snack, dinner }

/// What the dashboard suggests logging next ([nextCareAction]).
enum CareAction {
  breakfast(CareNeed.food),
  lunch(CareNeed.food),
  snack(CareNeed.food),
  dinner(CareNeed.food),
  drink(CareNeed.drink),
  gutFeeling(CareNeed.gutFeeling),

  /// Nothing open right now: the plain „Füttern" shortcut.
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
    this.glasses = 0,
    this.gutFeelings = 0,
    this.toilets = 0,
    this.lastMealAt,
  });

  static const mealGoal = 3;
  static const glassGoal = 6;
  static const gutFeelingGoal = 1;
  static const mlPerGlass = 250;

  final int meals;

  /// Today's drinks in glasses ([glassesForMl] of their total volume).
  final int glasses;
  final int gutFeelings;
  final int toilets;

  /// Local time of today's latest meal.
  final DateTime? lastMealAt;

  factory DailyCare.fromEntries(EntriesState s, DateTime now) {
    bool isToday(DateTime t) {
      final l = t.toLocal();
      return l.year == now.year && l.month == now.month && l.day == now.day;
    }

    final ml = s.drinks
        .where((d) => isToday(d.trackedAt))
        .fold<int>(0, (sum, d) => sum + d.amountMl);
    final mealTimes = [
      for (final e in s.meals)
        if (isToday(e.trackedAt)) e.trackedAt.toLocal(),
    ];
    return DailyCare(
      meals: mealTimes.length,
      lastMealAt: mealTimes.isEmpty
          ? null
          : mealTimes.reduce((a, b) => a.isAfter(b) ? a : b),
      glasses: glassesForMl(ml),
      gutFeelings: s.gutFeelings.where((e) => isToday(e.trackedAt)).length,
      toilets: s.toiletEntries.where((e) => isToday(e.trackedAt)).length,
    );
  }

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

/// Frühstück until 10:30, Mittagessen until 15:00, a snack until 17:00,
/// then Abendessen.
MealSlot mealSlotAt(DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  if (minutes < 10 * 60 + 30) return MealSlot.breakfast;
  if (minutes < 15 * 60) return MealSlot.lunch;
  if (minutes < 17 * 60) return MealSlot.snack;
  return MealSlot.dinner;
}

/// Since when a meal counts for [slot] on [now]'s day: breakfast from
/// midnight, lunch and the afternoon snack from 10:30, dinner from 17:00.
DateTime _slotStart(MealSlot slot, DateTime now) => switch (slot) {
  MealSlot.breakfast => DateTime(now.year, now.month, now.day),
  MealSlot.lunch ||
  MealSlot.snack => DateTime(now.year, now.month, now.day, 10, 30),
  MealSlot.dinner => DateTime(now.year, now.month, now.day, 17),
};

/// The next thing to log: the meal the time of day asks for until a meal
/// is logged in its slot (a skipped breakfast is not asked for at noon),
/// then Trinken under its goal, then Bauchgefühl, else [CareAction.feed].
/// Klo never drives it.
CareAction nextCareAction(DailyCare care, DateTime now) {
  final slot = mealSlotAt(now);
  final last = care.lastMealAt;
  final ateThisSlot = last != null && !last.isBefore(_slotStart(slot, now));
  if (!ateThisSlot && care.meals < DailyCare.mealGoal) {
    return switch (slot) {
      MealSlot.breakfast => CareAction.breakfast,
      MealSlot.lunch => CareAction.lunch,
      MealSlot.snack => CareAction.snack,
      MealSlot.dinner => CareAction.dinner,
    };
  }
  if (!care.isMet(CareNeed.drink)) return CareAction.drink;
  if (!care.isMet(CareNeed.gutFeeling)) return CareAction.gutFeeling;
  return CareAction.feed;
}
