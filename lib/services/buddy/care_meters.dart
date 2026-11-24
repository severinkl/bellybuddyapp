import '../../config/constants.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/gut_feeling_rating.dart';
import 'daily_care.dart';

/// The needs that have a meter; Klo has none.
const meteredNeeds = [CareNeed.food, CareNeed.drink, CareNeed.gutFeeling];

/// How long awake time takes to drain [need] from full, null for Klo.
Duration? drainOf(CareNeed need) => switch (need) {
  CareNeed.food => AppConstants.careFoodDrain,
  CareNeed.drink => AppConstants.careDrinkDrain,
  CareNeed.gutFeeling => AppConstants.careGutFeelingDrain,
  CareNeed.toilet => null,
};

/// The time between [from] and [to] that falls in the awake windows
/// (07:00–22:00 local); the night pause is left out.
Duration awakeBetween(DateTime from, DateTime to) {
  final start = from.toLocal();
  final end = to.toLocal();
  if (!end.isAfter(start)) return Duration.zero;
  var total = Duration.zero;
  final lastDay = DateTime(end.year, end.month, end.day);
  for (
    var day = DateTime(start.year, start.month, start.day);
    !day.isAfter(lastDay);
    day = addDays(day, 1)
  ) {
    final from0 = DateTime(
      day.year,
      day.month,
      day.day,
      AppConstants.careNightUntilHour,
    );
    final to0 = DateTime(
      day.year,
      day.month,
      day.day,
      AppConstants.careNightFromHour,
    );
    final lo = start.isAfter(from0) ? start : from0;
    final hi = end.isBefore(to0) ? end : to0;
    if (hi.isAfter(lo)) total += hi.difference(lo);
  }
  return total;
}

/// A need's level from 1.0 (just logged) down to the floor, linear in awake
/// time since [last]; a future [last] counts as just logged.
double meterLevel(DateTime? last, DateTime now, Duration drain) {
  const floor = AppConstants.careMeterFloor;
  if (last == null) return floor;
  final awake = awakeBetween(last, now).inMicroseconds;
  return (1 - (1 - floor) * awake / drain.inMicroseconds).clamp(floor, 1.0);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// „vor 3 Std", „gestern" … for [last] seen from [now].
String careAgo(DateTime last, DateTime now) {
  final l = last.toLocal();
  final n = now.toLocal();
  if (l.isAfter(n)) return 'um ${_two(l.hour)}:${_two(l.minute)}';
  final diff = n.difference(l);
  if (diff < const Duration(minutes: 10)) return 'gerade eben';
  if (diff < const Duration(hours: 1)) return 'vor ${diff.inMinutes} Min';
  final days = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(l.year, l.month, l.day));
  // Calendar days, rounded to absorb a DST hour.
  final dayCount = (days.inHours / 24).round();
  if (dayCount == 0) return 'vor ${diff.inHours} Std';
  if (dayCount == 1) return 'gestern';
  return 'vor $dayCount Tagen';
}

/// When each need was last logged (local), as far as the loaded days show.
class CareLog {
  const CareLog({
    this.lastMealAt,
    this.lastDrinkAt,
    this.lastGutFeelingAt,
    this.lastToiletAt,
    this.lastGutFeelingLevel,
  });

  final DateTime? lastMealAt;
  final DateTime? lastDrinkAt;
  final DateTime? lastGutFeelingAt;
  final DateTime? lastToiletAt;

  /// The loaded day's latest Bauchgefühl.
  final GutFeelingRatingLevel? lastGutFeelingLevel;

  DateTime? lastAt(CareNeed need) => switch (need) {
    CareNeed.food => lastMealAt,
    CareNeed.drink => lastDrinkAt,
    CareNeed.gutFeeling => lastGutFeelingAt,
    CareNeed.toilet => lastToiletAt,
  };

  /// Whether [need]'s last entry falls on [day]'s date.
  bool loggedOn(CareNeed need, DateTime day) {
    final at = lastAt(need);
    return at != null &&
        at.year == day.year &&
        at.month == day.month &&
        at.day == day.day;
  }

  bool anyOn(DateTime day) => CareNeed.values.any((n) => loggedOn(n, day));

  @override
  bool operator ==(Object other) =>
      other is CareLog &&
      other.lastMealAt == lastMealAt &&
      other.lastDrinkAt == lastDrinkAt &&
      other.lastGutFeelingAt == lastGutFeelingAt &&
      other.lastToiletAt == lastToiletAt &&
      other.lastGutFeelingLevel == lastGutFeelingLevel;

  @override
  int get hashCode => Object.hash(
    lastMealAt,
    lastDrinkAt,
    lastGutFeelingAt,
    lastToiletAt,
    lastGutFeelingLevel,
  );
}

/// The three need meters at one moment.
class CareMeters {
  const CareMeters({
    required this.food,
    required this.drink,
    required this.gutFeeling,
  });

  factory CareMeters.at(CareLog log, DateTime now) => CareMeters(
    food: meterLevel(log.lastMealAt, now, AppConstants.careFoodDrain),
    drink: meterLevel(log.lastDrinkAt, now, AppConstants.careDrinkDrain),
    gutFeeling: meterLevel(
      log.lastGutFeelingAt,
      now,
      AppConstants.careGutFeelingDrain,
    ),
  );

  final double food;
  final double drink;
  final double gutFeeling;

  /// [need]'s level, null for Klo.
  double? level(CareNeed need) => switch (need) {
    CareNeed.food => food,
    CareNeed.drink => drink,
    CareNeed.gutFeeling => gutFeeling,
    CareNeed.toilet => null,
  };

  /// The need with the lowest meter; ties go to food, drink, Bauchgefühl.
  CareNeed get lowest {
    var low = CareNeed.food;
    for (final need in meteredNeeds) {
      if (level(need)! < level(low)!) low = need;
    }
    return low;
  }

  @override
  bool operator ==(Object other) =>
      other is CareMeters &&
      other.food == food &&
      other.drink == drink &&
      other.gutFeeling == gutFeeling;

  @override
  int get hashCode => Object.hash(food, drink, gutFeeling);
}

/// The words under the meters and in their semantics.
abstract final class CareCopy {
  static const notToday = 'heute noch nicht';
  static const notYet = 'noch nicht eingetragen';

  /// Klo's line: how long ago, or [notToday] when not logged today.
  static String looLine(CareLog log, DateTime now) =>
      log.loggedOn(CareNeed.toilet, now)
      ? careAgo(log.lastToiletAt!, now)
      : notToday;

  /// A bubble's semantics value.
  static String spoken(CareNeed need, CareLog log, DateTime now) {
    if (need == CareNeed.toilet) {
      return log.loggedOn(need, now)
          ? 'zuletzt ${looLine(log, now)}'
          : notToday;
    }
    final last = log.lastAt(need);
    return last == null ? notYet : 'zuletzt ${careAgo(last, now)}';
  }
}
