import '../../config/constants.dart';
import '../../models/gut_feeling_entry.dart';
import '../../models/ingredient_suggestion_group.dart';
import '../../models/meal_entry.dart';
import '../../models/replacement_ingredient.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/gut_feeling_rating.dart';

/// The day a review is about; [yesterday] when it is the carried-over one.
class ReviewDay {
  const ReviewDay(this.day, {required this.yesterday});

  /// Local date (time of day ignored).
  final DateTime day;
  final bool yesterday;

  // Equal by value, so what watches the open day hears only of a new one,
  // not of every minute.
  @override
  bool operator ==(Object other) =>
      other is ReviewDay && other.day == day && other.yesterday == yesterday;

  @override
  int get hashCode => Object.hash(day, yesterday);
}

/// The day whose review is open at [now] (local), or null: today from
/// [reviewMinutes] on; otherwise yesterday until
/// [AppConstants.dailyReviewCarryOverHour]; a closed day is never open.
ReviewDay? openReviewDay({
  required DateTime now,
  required int reviewMinutes,
  required DateTime? closedDay,
}) {
  final today = startOfDay(now);
  final isClosed = closedDay != null && isSameDay(closedDay, today);
  final minutes = now.hour * 60 + now.minute;
  if (minutes >= reviewMinutes) {
    return isClosed ? null : ReviewDay(today, yesterday: false);
  }
  if (now.hour < AppConstants.dailyReviewCarryOverHour) {
    final yesterday = addDays(today, -1);
    if (closedDay != null && isSameDay(closedDay, yesterday)) return null;
    return ReviewDay(yesterday, yesterday: true);
  }
  return null;
}

/// 'HH:MM' → minutes, clamped to the allowed range; unparsable → 19:30.
int reviewMinutesOf(String? time) {
  int parse(String t) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t.trim());
    if (m == null) return -1;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return -1;
    return h * 60 + min;
  }

  var minutes = time == null ? -1 : parse(time);
  if (minutes < 0) minutes = parse(AppConstants.dailyReviewDefaultTime);
  return clampReviewMinutes(minutes);
}

/// [minutes] (since midnight) within the allowed range for the review time.
int clampReviewMinutes(int minutes) => minutes.clamp(
  AppConstants.dailyReviewEarliestMinutes,
  AppConstants.dailyReviewLatestMinutes,
);

/// Whether [trackedAt] (wall clock in the UTC slot) falls on local [day]:
/// compares the y/m/d fields only.
bool onWallClockDay(DateTime trackedAt, DateTime day) =>
    isSameDay(trackedAt, day);

class AlternativePick {
  const AlternativePick({
    required this.group,
    required this.replacement,
    required this.recentMeals,
  });

  final IngredientSuggestionGroup group;
  final ReplacementIngredient replacement;

  /// The group's meals in the recent days ending with the review day.
  final int recentMeals;
}

int _recentMeals(IngredientSuggestionGroup g, DateTime day) =>
    g.meals.where((m) {
      final back = daysBetween(m.trackedAt, day);
      return back >= 0 && back <= AppConstants.dailyReviewRecentDays - 1;
    }).length;

/// The tier from which a replacement is never picked: a sibling (same base
/// name) of one skipped on any pairing, or skipped itself.
const _neverPickedTier = 3;

/// The alternative for the review of [day]: spec §4.2. Never one whose base
/// name the user skipped on any pairing ([RankedReplacement.tier] ≥ 3; the
/// groups are ranked with the choices).
AlternativePick? pickAlternative({
  required List<IngredientSuggestionGroup> groups,
  required Set<String> dayMealIds,
  required Set<(String, String)> chosen,
  required DateTime day,
}) {
  final candidates = [
    for (final g in groups)
      if (g.replacements.isNotEmpty &&
          g.meals.any((m) => dayMealIds.contains(m.id)))
        (group: g, recent: _recentMeals(g, day)),
  ];
  candidates.sort((a, b) {
    if (a.recent != b.recent) return b.recent.compareTo(a.recent);
    final la = a.group.latestMeal;
    final lb = b.group.latestMeal;
    if (la != lb) {
      if (la == null) return 1;
      if (lb == null) return -1;
      return lb.compareTo(la);
    }
    return a.group.ingredientName.toLowerCase().compareTo(
      b.group.ingredientName.toLowerCase(),
    );
  });
  for (final c in candidates) {
    for (final r in c.group.replacements) {
      if (r.tier < _neverPickedTier &&
          !chosen.contains((c.group.ingredientId, r.id))) {
        return AlternativePick(
          group: c.group,
          replacement: r.replacement,
          recentMeals: c.recent,
        );
      }
    }
  }
  return null;
}

/// A line of the card besides the fixed ones; tappable with a [route].
class DailyReviewLine {
  const DailyReviewLine(this.text, {this.route});

  final String text;
  final String? route;
}

class DailyReview {
  const DailyReview({
    required this.day,
    required this.meals,
    required this.lastGut,
    required this.alternative,
    required this.alternativeLocked,
    required this.extras,
    this.alternativePending = false,
  });

  final ReviewDay day;
  final int meals;
  final GutFeelingRatingLevel? lastGut;
  final AlternativePick? alternative;
  final bool alternativeLocked;
  final List<DailyReviewLine> extras;

  /// The suggestions or the choices are still on their first load: no
  /// [alternative] yet, and the card shows no alternative block (neither a
  /// claim of none nor a pick it may have to take back).
  final bool alternativePending;
}

/// Null without a meal on that day. [DailyReview.lastGut] is the level of the
/// day's latest gut-feeling entry by trackedAt. [alternativeLocked] keeps the
/// pick (the card hides its names). [alternativePending]: no pick yet.
DailyReview? buildDailyReview({
  required ReviewDay day,
  required List<MealEntry> meals,
  required List<GutFeelingEntry> gutFeelings,
  required List<IngredientSuggestionGroup> groups,
  required Set<(String, String)> chosen,
  bool alternativeLocked = false,
  bool alternativePending = false,
  List<DailyReviewLine> extras = const [],
}) {
  final dayMeals = meals.where((m) => onWallClockDay(m.trackedAt, day.day));
  if (dayMeals.isEmpty) return null;
  GutFeelingEntry? latest;
  for (final g in gutFeelings) {
    if (!onWallClockDay(g.trackedAt, day.day)) continue;
    if (latest == null || g.trackedAt.isAfter(latest.trackedAt)) latest = g;
  }
  return DailyReview(
    day: day,
    meals: dayMeals.length,
    lastGut: latest == null ? null : calculateGutFeelingRating(latest).level,
    alternative: alternativePending
        ? null
        : pickAlternative(
            groups: groups,
            dayMealIds: {for (final m in dayMeals) m.id},
            chosen: chosen,
            day: day.day,
          ),
    alternativeLocked: alternativeLocked,
    alternativePending: alternativePending,
    extras: extras,
  );
}
