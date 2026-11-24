import 'dart:math';

import '../../config/constants.dart';
import '../../models/gut_feeling_entry.dart';
import '../../models/toilet_entry.dart';
import '../../utils/gut_feeling_rating.dart';
import '../../widgets/buddy/buddy_actions.dart';
import '../../widgets/buddy/buddy_pose.dart';
import 'buddy_copy.dart';
import 'care_meters.dart';
import 'daily_care.dart';

enum EntryKind { meal, drink, toilet, gutFeeling }

/// The need an entry of [kind] fills.
CareNeed careNeedOf(EntryKind kind) => switch (kind) {
  EntryKind.meal => CareNeed.food,
  EntryKind.drink => CareNeed.drink,
  EntryKind.gutFeeling => CareNeed.gutFeeling,
  EntryKind.toilet => CareNeed.toilet,
};

enum LogSentiment { good, neutral, bad }

/// The Buddy's resting mood from his need meters at [now]: sleepy before
/// [DayParts.awakeFrom] while nothing is logged today, energetic with every
/// meter at [AppConstants.careMeterHigh] or more, happy with none under
/// [AppConstants.careMeterLow], else hungry from [DayParts.awakeFrom] until
/// [DayParts.nightFrom] and sleepy otherwise.
BuddyMood deriveBuddyMood(CareLog log, DateTime now) {
  final minute = DayParts.minuteOf(now);
  final awake = minute >= DayParts.awakeFrom;
  if (!log.anyOn(now) && !awake) return BuddyMood.sleepy;
  final lowest = CareMeters.at(log, now).lowestLevel;
  if (lowest >= AppConstants.careMeterHigh) return BuddyMood.energetic;
  if (lowest >= AppConstants.careMeterLow) return BuddyMood.happy;
  if (awake && minute < DayParts.nightFrom) return BuddyMood.hungry;
  return BuddyMood.sleepy;
}

LogSentiment sentimentForGutFeeling(GutFeelingEntry e) {
  switch (calculateGutFeelingRating(e).level) {
    case GutFeelingRatingLevel.spiGut:
    case GutFeelingRatingLevel.gut:
      return LogSentiment.good;
    case GutFeelingRatingLevel.mittel:
      return LogSentiment.neutral;
    case GutFeelingRatingLevel.schlecht:
      return LogSentiment.bad;
  }
}

LogSentiment sentimentForToilet(ToiletEntry e) {
  if (e.stoolType == 3) return LogSentiment.good;
  if (e.stoolType == 1 || e.stoolType == 5) return LogSentiment.bad;
  return LogSentiment.neutral;
}

class BuddyReaction {
  const BuddyReaction(this.action, this.line, {this.moodAfter});

  final BuddyAction action;
  final String line;
  final BuddyMood? moodAfter;
}

BuddyReaction reactionFor(
  EntryKind kind,
  LogSentiment sentiment, {
  required String name,
  required Random rnd,
}) {
  BuddyReaction make(BuddyAction a, List<String> pool, {BuddyMood? after}) =>
      BuddyReaction(
        a,
        BuddyCopy.fill(BuddyCopy.pick(pool, rnd), name: name),
        moodAfter: after,
      );

  switch (kind) {
    case EntryKind.meal:
      return make(BuddyAction.eat, BuddyCopy.meal);
    case EntryKind.drink:
      return make(BuddyAction.drink, BuddyCopy.drink);
    case EntryKind.toilet:
      return sentiment == LogSentiment.bad
          ? make(
              BuddyAction.hug,
              BuddyCopy.toiletBad,
              after: BuddyMood.empathetic,
            )
          : make(BuddyAction.relief, BuddyCopy.relief);
    case EntryKind.gutFeeling:
      switch (sentiment) {
        case LogSentiment.good:
          return make(BuddyAction.celebrate, BuddyCopy.gutGood);
        case LogSentiment.neutral:
          return make(BuddyAction.nodYes, BuddyCopy.gutNeutral);
        case LogSentiment.bad:
          return make(
            BuddyAction.hug,
            BuddyCopy.gutBad,
            after: BuddyMood.empathetic,
          );
      }
  }
}

/// A resting-mood line; sleepy outside the morning ([DayParts.dayFrom]
/// until [DayParts.awakeFrom]) means night ([BuddyCopy.sleepyNight]).
/// Lines quoting the streak („{streak} Tage in Folge") are only used from a
/// streak of 2 days on. Never [avoid] (the line said last) while the pool
/// has another.
String moodLine(
  BuddyMood mood, {
  required String name,
  required int streak,
  required DateTime now,
  required Random rnd,
  String? avoid,
}) {
  final minute = DayParts.minuteOf(now);
  final morning = minute >= DayParts.dayFrom && minute < DayParts.awakeFrom;
  final all = mood == BuddyMood.sleepy && !morning
      ? BuddyCopy.sleepyNight
      : BuddyCopy.mood[mood]!;
  final withoutStreak = [
    for (final line in all)
      if (!line.contains('{streak}')) line,
  ];
  final pool = streak >= 2 || withoutStreak.isEmpty ? all : withoutStreak;
  final lines = [
    for (final line in pool) BuddyCopy.fill(line, name: name, streak: streak),
  ];
  final fresh = [
    for (final line in lines)
      if (line != avoid) line,
  ];
  return BuddyCopy.pick(fresh.isEmpty ? lines : fresh, rnd);
}
