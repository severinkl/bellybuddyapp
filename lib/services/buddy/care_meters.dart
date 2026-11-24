import '../../config/constants.dart';
import '../../providers/entries_provider.dart';
import '../../models/gut_feeling_entry.dart';
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

/// The time between [from] and [to] that falls in the meters' awake
/// windows ([DayParts.metersFrom] until [DayParts.nightFrom], local); the
/// night pause is left out.
Duration awakeBetween(DateTime from, DateTime to) {
  if (!to.isAfter(from)) return Duration.zero;
  var total = Duration.zero;
  final lastDay = startOfDay(to);
  for (
    var day = startOfDay(from);
    !day.isAfter(lastDay);
    day = addDays(day, 1)
  ) {
    final from0 = DayParts.at(day, DayParts.metersFrom);
    final to0 = DayParts.at(day, DayParts.nightFrom);
    final lo = from.isAfter(from0) ? from : from0;
    final hi = to.isBefore(to0) ? to : to0;
    if (hi.isAfter(lo)) total += hi.difference(lo);
  }
  return total;
}

/// Any two days hold more awake time than the longest drain: a need last
/// logged longer ago than this is at the floor, without counting.
const _drainedAfter = Duration(days: 2);

/// A need's level from 1.0 (just logged) down to the floor, linear in awake
/// time since [last]; a future [last] counts as just logged.
double meterLevel(DateTime? last, DateTime now, Duration drain) {
  const floor = AppConstants.careMeterFloor;
  if (last == null || now.difference(last) > _drainedAfter) return floor;
  final awake = awakeBetween(last, now).inMicroseconds;
  return (1 - (1 - floor) * awake / drain.inMicroseconds).clamp(floor, 1.0);
}

/// „vor 3 Std", „gestern" … for [last] seen from [now].
String careAgo(DateTime last, DateTime now) {
  if (last.isAfter(now)) return 'um ${formatTime(last)}';
  final diff = now.difference(last);
  if (diff < const Duration(minutes: 10)) return 'gerade eben';
  if (diff < const Duration(hours: 1)) return 'vor ${diff.inMinutes} Min';
  final days = startOfDay(now).difference(startOfDay(last));
  // Calendar days, rounded to absorb a DST hour.
  final dayCount = (days.inHours / 24).round();
  if (dayCount == 0) return 'vor ${diff.inHours} Std';
  if (dayCount == 1) return 'gestern';
  return 'vor $dayCount Tagen';
}

/// The latest of [items] by [at] (the first of a tie), null when there is
/// none.
E? _latest<E>(Iterable<E> items, DateTime Function(E) at) => items.fold(
  null,
  (last, e) => last == null || at(e).isAfter(at(last)) ? e : last,
);

DateTime _self(DateTime t) => t;

/// When each need was last logged (local), as far as the loaded days show.
class CareLog {
  const CareLog({
    this.lastMealAt,
    this.lastDrinkAt,
    this.lastGutFeelingAt,
    this.lastToiletAt,
    this.lastGutFeelingLevel,
  });

  /// The log as [s] shows it at [day]: each need's latest entry of the
  /// loaded day or, failing that, of the days before ([EntriesState
  /// .latestBefore]). Klo has only the loaded day's.
  factory CareLog.fromEntries(EntriesState s, DateTime day) {
    final todaysGutFeeling = _latest(
      s.gutFeelings.where((g) => isSameDay(g.trackedAt, day)),
      (GutFeelingEntry g) => g.trackedAt,
    );
    final before = s.latestBefore;
    return CareLog(
      lastMealAt: _latest([
        ...s.meals.map((e) => e.trackedAt),
        ?before.meal,
      ], _self),
      lastDrinkAt: _latest([
        ...s.drinks.map((e) => e.trackedAt),
        ?before.drink,
      ], _self),
      lastGutFeelingAt: _latest([
        ...s.gutFeelings.map((e) => e.trackedAt),
        ?before.gutFeeling,
      ], _self),
      lastToiletAt: _latest(s.toiletEntries.map((e) => e.trackedAt), _self),
      lastGutFeelingLevel: todaysGutFeeling == null
          ? null
          : calculateGutFeelingRating(todaysGutFeeling).level,
    );
  }

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
    return at != null && isSameDay(at, day);
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

  factory CareMeters.at(CareLog log, DateTime now) {
    double at(CareNeed need) =>
        meterLevel(log.lastAt(need), now, drainOf(need)!);
    return CareMeters(
      food: at(CareNeed.food),
      drink: at(CareNeed.drink),
      gutFeeling: at(CareNeed.gutFeeling),
    );
  }

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

  /// The [lowest] meter's level.
  double get lowestLevel => level(lowest)!;

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

  /// A bubble's semantics value; Bauchgefühl's also names how today's
  /// latest one was („zuletzt vor 2 Std, Mittel").
  static String spoken(CareNeed need, CareLog log, DateTime now) {
    if (need == CareNeed.toilet) {
      final line = looLine(log, now);
      return line == notToday ? line : 'zuletzt $line';
    }
    final last = log.lastAt(need);
    if (last == null) return notYet;
    final ago = 'zuletzt ${careAgo(last, now)}';
    final level = need == CareNeed.gutFeeling ? log.lastGutFeelingLevel : null;
    return level == null ? ago : '$ago, ${level.label}';
  }
}
