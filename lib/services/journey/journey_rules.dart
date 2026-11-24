import 'dart:math' as math;

import '../../models/insight_rules.dart';
import '../../models/insights.dart';
import '../../models/journey_rewards.dart';
import '../../models/recipe.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/distinct_by_name.dart';
import '../../utils/food_words.dart';
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

/// Day 3's reward ([day3Of]): the one rule for its title, detail, sheet,
/// action, pick and announcement.
enum Day3 {
  /// Not decided yet (before day 3, or the weekly tips unknown when it
  /// came), the weekly tips not on: the first tip, waiting.
  waiting,

  /// Offered, waiting for „Ja, gern" or „Nein, danke" (answerable once the
  /// weekly tips are known to be off: [tipOfferDue]): the first tip. Its
  /// recipe is picked meanwhile, in case the offer goes.
  offerOpen,

  /// „Ja, gern": the first tip.
  tip,

  /// A recipe: „Nein, danke", the offer skipped (the weekly tips on at day
  /// 3), or the weekly tips on now while it was open or undecided.
  recipe,
}

/// Day 3's reward as of [r]'s offer and the weekly tips ([weeklyTips], null
/// while unknown).
Day3 day3Of(JourneyRewards r, {required bool? weeklyTips}) =>
    switch (r.tipOffer) {
      TipOffer.accepted => Day3.tip,
      TipOffer.declined || TipOffer.skipped => Day3.recipe,
      _ when weeklyTips == true => Day3.recipe,
      TipOffer.offered when r.earnedDay >= _tipDay => Day3.offerOpen,
      TipOffer.offered || null => Day3.waiting,
    };

/// [r] with the recipes of the earned recipe days that have none yet, in
/// day order, each another recipe than those picked before. Day 3 once the
/// offer is open or it is a recipe ([day3Of] with [weeklyTips]); day 5
/// prefers the [calmKeys] (`Insights.calmDayIngredients`).
///
/// Nothing while [ranked] is unchecked; a stored pick is never replaced.
/// [r] itself when nothing was picked.
JourneyRewards fillPicks(
  JourneyRewards r, {
  required RankedRecipes ranked,
  required Set<String> calmKeys,
  required bool? weeklyTips,
}) {
  if (!ranked.checked) return r;
  final picks = {...r.picks};
  for (final day in JourneyRewards.recipeDays) {
    if (day > r.earnedDay || picks.containsKey(day)) continue;
    if (day == _tipDay) {
      switch (day3Of(r, weeklyTips: weeklyTips)) {
        case Day3.waiting || Day3.tip:
          continue;
        case Day3.offerOpen || Day3.recipe:
          break;
      }
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
/// [exclude]: the first that [passesForYou] with a line that is one of the
/// foods [goodKeys] (`RecipeIngredient.isFood`: also in another spelling,
/// like core), naming those lines, else the first, naming none. Null when
/// none is left.
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
    final good = [for (final key in goodKeys) FoodName.of(key)];
    for (final fit in order.where(passesForYou)) {
      final matched = _matchedLines(fit.recipe, good);
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

/// The names of [recipe]'s lines that are one of [foods], as the recipe
/// spells them, in recipe order, each once (case ignored), at most
/// [_maxMatched].
List<String> _matchedLines(Recipe recipe, List<FoodName> foods) =>
    List.unmodifiable(
      distinctByName([
        for (final line in recipe.ingredients)
          if (foods.any(line.isFood)) line.name.trim(),
      ], (name) => name).take(_maxMatched),
    );

/// The day the Buddy announces: the earned day while it is 1–6, but day 3
/// only when the offer was skipped (otherwise the offer itself, or the
/// answer's sheet, stands for it). Day 7 is the celebration's.
int? announcementDay(JourneyRewards r, {required bool? weeklyTips}) {
  final day = r.earnedDay;
  if (day < 1 || day >= _patternsDay) return null;
  if (day != _tipDay) return day;
  return switch (day3Of(r, weeklyTips: weeklyTips)) {
    Day3.waiting || Day3.offerOpen || Day3.tip => null,
    Day3.recipe => r.tipOffer == TipOffer.skipped ? day : null,
  };
}

/// [r] with the day-3 offer answered: [TipOffer.offered] becomes accepted
/// or declined; [r] itself while undecided or once answered.
JourneyRewards answerOffer(JourneyRewards r, {required bool accepted}) =>
    r.tipOffer == TipOffer.offered
    ? r.copyWith(tipOffer: accepted ? TipOffer.accepted : TipOffer.declined)
    : r;

/// Whether the day-3 offer of a first tip is waiting for an answer: open
/// ([Day3.offerOpen]), with the weekly tips known to be off.
bool tipOfferDue(JourneyRewards r, {required bool? weeklyTips}) =>
    switch (day3Of(r, weeklyTips: weeklyTips)) {
      Day3.offerOpen => weeklyTips == false,
      Day3.waiting || Day3.tip || Day3.recipe => false,
    };

/// Whether [day]'s reward is earned: days 1–6 up to the earned day, day 7
/// once the patterns were freed.
bool rewardEarned(int day, JourneyRewards r) => day == _patternsDay
    ? r.patternsFreed
    : day >= 1 && day < _patternsDay && day <= r.earnedDay;

/// The recipe [day]'s reward shows and opens: the stored pick of a recipe
/// day ([JourneyRewards.recipeDays]); null on another day, without a pick,
/// and on day 3 unless that is a recipe ([day3Of]): a recipe picked while
/// the offer waits is not the reward then.
RecipePick? rewardPick(
  int day,
  JourneyRewards r, {
  required bool? weeklyTips,
}) => day != _tipDay
    ? r.picks[day]
    : switch (day3Of(r, weeklyTips: weeklyTips)) {
        Day3.recipe => r.picks[day],
        Day3.waiting || Day3.offerOpen || Day3.tip => null,
      };

/// The title of [day]'s reward (1–7). Day 3 is the tip or a recipe as
/// [day3Of] says; day 5 names the user's ingredients only once a stored
/// pick matched some, and is generic before that and without a match.
String rewardTitle(int day, JourneyRewards r, {required bool? weeklyTips}) =>
    switch (day) {
      1 => JourneyCopy.day1,
      2 => JourneyCopy.day2,
      3 => switch (day3Of(r, weeklyTips: weeklyTips)) {
        Day3.waiting || Day3.offerOpen || Day3.tip => JourneyCopy.day3Tip,
        Day3.recipe => JourneyCopy.day3Recipe,
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
