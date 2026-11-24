import 'dart:math' as math;

import '../../models/insight_rules.dart';
import '../../models/insights.dart';
import '../../models/journey_rewards.dart';
import '../../models/recipe.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/distinct_by_name.dart';
import '../recipes/recipe_fit.dart';
import '../recipes/recipe_ranking.dart';
import 'journey_copy.dart';

/// The day of the first-tip offer.
const _tipDay = 3;

/// The day of the calm-day recipe.
const _calmDay = 5;

/// The last day: the first patterns.
const _patternsDay = InsightRules.daysNeeded;

/// Day 5 names at most this many matched lines.
const _maxMatched = 3;

/// [r] moved on by [insights] and the weekly tips ([weeklyTips], null while
/// unknown):
/// - the earned day follows the active days, at most [_patternsDay], and
///   never goes down;
/// - the patterns are freed once [insights] are unlocked, and stay freed;
/// - from day 3 the offer is decided once the weekly tips are known: off →
///   [TipOffer.offered], on → [TipOffer.skipped].
///
/// [r] itself when nothing changed.
JourneyRewards advanceRewards(
  JourneyRewards r, {
  required Insights insights,
  required bool? weeklyTips,
}) {
  final earnedDay = math.max(
    r.earnedDay,
    math.min(insights.progress.activeDays, _patternsDay),
  );
  final next = r.copyWith(
    earnedDay: earnedDay,
    patternsFreed: r.patternsFreed || insights.unlocked,
    tipOffer: r.tipOffer == null && earnedDay >= _tipDay && weeklyTips != null
        ? (weeklyTips ? TipOffer.skipped : TipOffer.offered)
        : null,
  );
  return next == r ? r : next;
}

/// [r] with the recipes of the earned recipe days that have none yet, in
/// day order, each another recipe than those picked before. Day 3 only once
/// the offer is decided and not accepted; day 5 prefers the [calmKeys]
/// (`Insights.calmDayIngredients`).
///
/// Nothing while [ranked] is unchecked; a stored pick is never replaced.
/// [r] itself when nothing was picked.
JourneyRewards fillPicks(
  JourneyRewards r, {
  required RankedRecipes ranked,
  required Set<String> calmKeys,
}) {
  if (!ranked.checked) return r;
  final picks = {...r.picks};
  for (final day in JourneyRewards.recipeDays) {
    if (day > r.earnedDay || picks.containsKey(day)) continue;
    if (day == _tipDay &&
        (r.tipOffer == null || r.tipOffer == TipOffer.accepted)) {
      continue;
    }
    final pick = pickJourneyRecipe(
      ranked.fits,
      exclude: {for (final p in picks.values) p.id},
      goodKeys: day == _calmDay ? calmKeys : const {},
    );
    if (pick != null) picks[day] = pick;
  }
  return picks.length == r.picks.length
      ? r
      : r.copyWith(picks: Map.unmodifiable(picks));
}

/// A recipe of [ranked] in „Für dich" order ([pickForYou]) that is not in
/// [exclude]: the first that [passesForYou] with a line matching [goodKeys]
/// (`RecipeIngredient.matchKeys`), naming those lines, else the first,
/// naming none. Null when none is left.
RecipePick? pickJourneyRecipe(
  List<RecipeFit> ranked, {
  Set<String> exclude = const {},
  Set<String> goodKeys = const {},
}) {
  final order = [
    for (final fit in pickForYou(ranked, count: ranked.length))
      if (!exclude.contains(fit.recipe.id)) fit,
  ];
  if (goodKeys.isNotEmpty) {
    for (final fit in order.where(passesForYou)) {
      final matched = _matchedLines(fit.recipe, goodKeys);
      if (matched.isNotEmpty) {
        return RecipePick(
          id: fit.recipe.id,
          title: fit.recipe.title,
          matched: matched,
        );
      }
    }
  }
  if (order.isEmpty) return null;
  final first = order.first.recipe;
  return RecipePick(id: first.id, title: first.title);
}

/// The names of [recipe]'s lines matching [keys], in recipe order, each
/// once (case ignored), at most [_maxMatched].
List<String> _matchedLines(Recipe recipe, Set<String> keys) =>
    List.unmodifiable(
      distinctByName([
        for (final line in recipe.ingredients)
          if (line.matchKeys.any(keys.contains)) line.name.trim(),
      ], (name) => name).take(_maxMatched),
    );

/// The day the Buddy announces: the earned day while it is 1–6, but day 3
/// only when the offer was skipped (otherwise the offer itself, or the
/// answer's sheet, stands for it). Day 7 is the celebration's.
int? announcementDay(JourneyRewards r) {
  final day = r.earnedDay;
  if (day < 1 || day >= _patternsDay) return null;
  if (day == _tipDay && r.tipOffer != TipOffer.skipped) return null;
  return day;
}

/// [r] with the day-3 offer answered: [TipOffer.offered] becomes accepted
/// or declined; [r] itself while undecided or once answered.
JourneyRewards answerOffer(JourneyRewards r, {required bool accepted}) =>
    r.tipOffer == TipOffer.offered
    ? r.copyWith(tipOffer: accepted ? TipOffer.accepted : TipOffer.declined)
    : r;

/// Whether the day-3 offer of a first tip is waiting for an answer: earned,
/// offered and still unanswered, with the weekly tips known to be off.
bool tipOfferDue(JourneyRewards r, {required bool? weeklyTips}) =>
    r.earnedDay >= _tipDay &&
    r.tipOffer == TipOffer.offered &&
    weeklyTips == false;

/// Whether [day]'s reward is earned: days 1–6 up to the earned day, day 7
/// once the patterns were freed.
bool rewardEarned(int day, JourneyRewards r) => day == _patternsDay
    ? r.patternsFreed
    : day >= 1 && day < _patternsDay && day <= r.earnedDay;

/// The title of [day]'s reward (1–7). Day 3 is the tip once accepted, a
/// recipe once declined or skipped, and before that whatever the weekly
/// tips make it; day 5 names the user's ingredients only once a stored pick
/// matched some, and is generic before that and without a match.
String rewardTitle(int day, JourneyRewards r, {required bool? weeklyTips}) =>
    switch (day) {
      1 => JourneyCopy.day1,
      2 => JourneyCopy.day2,
      3 => switch (r.tipOffer) {
        TipOffer.accepted => JourneyCopy.day3Tip,
        TipOffer.declined || TipOffer.skipped => JourneyCopy.day3Recipe,
        TipOffer.offered || null =>
          weeklyTips == true ? JourneyCopy.day3Recipe : JourneyCopy.day3Tip,
      },
      4 => JourneyCopy.day4,
      5 =>
        r.picks[_calmDay]?.matched.isNotEmpty == true
            ? JourneyCopy.day5
            : JourneyCopy.day5Generic,
      6 => JourneyCopy.day6,
      7 => JourneyCopy.day7,
      _ => throw ArgumentError.value(day, 'day', 'not a journey day'),
    };

/// The day-4 saying of [userId]: stable without storage, and different
/// users get different ones.
String sayingFor(String userId) {
  final sum = userId.codeUnits.fold(0, (a, b) => a + b);
  return JourneyCopy.sayings[sum % JourneyCopy.sayings.length];
}

/// The reward line below the journey's counters.
class JourneyRewardLine {
  const JourneyRewardLine(this.text, {required this.day, required this.earned});

  final String text;

  /// The day it names, 1–7.
  final int day;

  /// Whether that day's reward is already earned („Heute: …").
  final bool earned;

  @override
  bool operator ==(Object other) =>
      other is JourneyRewardLine &&
      other.text == text &&
      other.day == day &&
      other.earned == earned;

  @override
  int get hashCode => Object.hash(text, day, earned);

  @override
  String toString() => 'JourneyRewardLine($text, day: $day, earned: $earned)';
}

/// The reward line as of [now]: today's reward („Heute: …") once today's
/// dot is filled (the journey's last day is [now]'s local day), else the
/// next one („Heute wartet: …"). Day 7 is „Bald: …" unless today's entry
/// alone could unlock it (no Bauchgefühl missing).
JourneyRewardLine rewardLine(
  JourneyRewards r, {
  required Insights insights,
  required DateTime now,
  required bool? weeklyTips,
}) {
  final n = r.earnedDay;
  final journey = insights.journey;
  final filled = journey.isNotEmpty && isSameDay(journey.last.day, now);
  if (filled && n >= 1 && n < _patternsDay) {
    return JourneyRewardLine(
      JourneyCopy.today(rewardTitle(n, r, weeklyTips: weeklyTips)),
      day: n,
      earned: true,
    );
  }
  final next = filled ? _patternsDay : math.min(n + 1, _patternsDay);
  if (next == _patternsDay) {
    final waiting = !filled && insights.progress.gutFeelingsLeft == 0;
    return JourneyRewardLine(
      waiting
          ? JourneyCopy.waiting(JourneyCopy.day7)
          : JourneyCopy.soon(JourneyCopy.day7),
      day: _patternsDay,
      earned: false,
    );
  }
  return JourneyRewardLine(
    JourneyCopy.waiting(rewardTitle(next, r, weeklyTips: weeklyTips)),
    day: next,
    earned: false,
  );
}
