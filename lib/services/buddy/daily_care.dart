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
/// midnight.
abstract final class DayParts {
  /// Mittagessen is asked for from here (Frühstück before).
  static const lunchFrom = 10 * 60 + 30;

  /// The afternoon snack.
  static const snackFrom = 15 * 60;

  /// Abendessen.
  static const dinnerFrom = 17 * 60;

  /// The dashboard Buddy's resting line names his next need by day, from
  /// [dayFrom] until [nightFrom]. Breakfast is asked for from [dayFrom]
  /// on.
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

/// The next thing to log: the need with the lowest meter
/// ([CareMeters.lowest]; Klo has none, so it never drives it) once it is
/// under [AppConstants.careMeterLow]. For Essen that is the meal the time
/// of day asks for ([mealSlotAt]), at night the plain „Essen eintragen"
/// ([CareAction.feed]). With no meter that low: [CareAction.feed].
CareAction nextCareAction(CareLog log, DateTime now) {
  final m = CareMeters.at(log, now);
  final lowest = m.lowest;
  if (m.level(lowest)! >= AppConstants.careMeterLow) return CareAction.feed;
  return switch (lowest) {
    CareNeed.food => mealSlotAt(now) ?? CareAction.feed,
    CareNeed.drink => CareAction.drink,
    CareNeed.gutFeeling => CareAction.gutFeeling,
    // Not metered, so never the lowest.
    CareNeed.toilet => CareAction.feed,
  };
}
