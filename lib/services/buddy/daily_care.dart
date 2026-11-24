import '../../config/constants.dart';
import 'care_meters.dart';

/// The Buddy's four needs, one per tracker; they make up the dashboard's
/// care ring.
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

/// The Buddy's day: where its parts start, in minutes after local
/// midnight. The night runs from [nightFrom] until [dayFrom] ([isDay]).
abstract final class DayParts {
  /// The day starts: the dashboard Buddy's resting line names his next
  /// need from here until [nightFrom]. Breakfast is asked for from here on.
  static const dayFrom = 5 * 60;

  /// The need meters drain from here until [nightFrom]; they pause
  /// overnight.
  static const metersFrom = 7 * 60;

  /// Until here he is sleepy while nothing is logged today; from here until
  /// [nightFrom] a low meter makes him hungry.
  static const awakeFrom = 10 * 60;

  /// Mittagessen is asked for from here (Frühstück before).
  static const lunchFrom = 10 * 60 + 30;

  /// The afternoon snack.
  static const snackFrom = 15 * 60;

  /// Abendessen.
  static const dinnerFrom = 17 * 60;

  /// The night starts: the meters pause, his resting line and his hunger
  /// end.
  static const nightFrom = 22 * 60;

  /// [t]'s minutes after midnight.
  static int minuteOf(DateTime t) => t.hour * 60 + t.minute;

  /// [day]'s local time [minute] minutes after midnight.
  static DateTime at(DateTime day, int minute) =>
      DateTime(day.year, day.month, day.day, 0, minute);

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

/// Where each meal slot ([mealSlotAt]) starts, in minutes after midnight.
const _slotFrom = {
  CareAction.breakfast: DayParts.dayFrom,
  CareAction.lunch: DayParts.lunchFrom,
  CareAction.snack: DayParts.snackFrom,
  CareAction.dinner: DayParts.dinnerFrom,
};

/// The meal to ask for when Essen is low at [now]: the one the time of day
/// asks for ([mealSlotAt]), or a snack once a meal is logged in that slot
/// (he never says a logged meal is still to come). At night the plain
/// „Essen eintragen" ([CareAction.feed]).
CareAction _mealAt(CareLog log, DateTime now) {
  final slot = mealSlotAt(now);
  if (slot == null) return CareAction.feed;
  final slotStart = DayParts.at(now, _slotFrom[slot]!);
  final last = log.lastMealAt;
  return last != null && !last.isBefore(slotStart) ? CareAction.snack : slot;
}

/// The next thing to log: the need with the lowest meter
/// ([CareMeters.lowest]; Klo has none, so it never drives it) once it is
/// under [AppConstants.careMeterLow]. For Essen that is a meal
/// ([_mealAt]). With no meter that low: [CareAction.feed].
CareAction nextCareAction(CareLog log, DateTime now) {
  final m = CareMeters.at(log, now);
  if (m.lowestLevel >= AppConstants.careMeterLow) return CareAction.feed;
  return switch (m.lowest) {
    CareNeed.food => _mealAt(log, now),
    CareNeed.drink => CareAction.drink,
    CareNeed.gutFeeling => CareAction.gutFeeling,
    // Not metered, so never the lowest.
    CareNeed.toilet => CareAction.feed,
  };
}
