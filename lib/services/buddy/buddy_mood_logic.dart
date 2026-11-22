import 'dart:math';

import '../../models/gut_feeling_entry.dart';
import '../../models/toilet_entry.dart';
import '../../providers/entries_provider.dart';
import '../../utils/gut_feeling_rating.dart';
import '../../widgets/buddy/buddy_actions.dart';
import '../../widgets/buddy/buddy_pose.dart';
import 'buddy_copy.dart';

enum EntryKind { meal, drink, toilet, gutFeeling }

enum LogSentiment { good, neutral, bad }

/// What the user logged today (local time).
class TodayCare {
  const TodayCare({this.count = 0, this.kinds = const {}, this.lastLogAt});

  final int count;
  final Set<EntryKind> kinds;
  final DateTime? lastLogAt;

  factory TodayCare.fromEntries(EntriesState s, DateTime now) {
    bool isToday(DateTime t) {
      final l = t.toLocal();
      return l.year == now.year && l.month == now.month && l.day == now.day;
    }

    var count = 0;
    final kinds = <EntryKind>{};
    DateTime? last;
    void add(EntryKind kind, Iterable<DateTime> times) {
      for (final t in times.where(isToday)) {
        count++;
        kinds.add(kind);
        final l = t.toLocal();
        if (last == null || l.isAfter(last!)) last = l;
      }
    }

    add(EntryKind.meal, s.meals.map((e) => e.trackedAt));
    add(EntryKind.drink, s.drinks.map((e) => e.trackedAt));
    add(EntryKind.toilet, s.toiletEntries.map((e) => e.trackedAt));
    add(EntryKind.gutFeeling, s.gutFeelings.map((e) => e.trackedAt));
    return TodayCare(count: count, kinds: kinds, lastLogAt: last);
  }
}

BuddyMood deriveBuddyMood(TodayCare care, DateTime now) {
  final h = now.hour;
  if (care.count == 0 && h < 10) return BuddyMood.sleepy;
  if (care.kinds.length >= 3) return BuddyMood.energetic;
  if (care.lastLogAt != null &&
      now.difference(care.lastLogAt!) < const Duration(hours: 5)) {
    return BuddyMood.happy;
  }
  if (h >= 10 && h < 22) return BuddyMood.hungry;
  return BuddyMood.sleepy;
}

LogSentiment sentimentForGutFeeling(GutFeelingEntry e) {
  switch (calculateGutFeelingRating(e).level) {
    case GutFeelingRatingLevel.spiGut:
    case GutFeelingRatingLevel.gut:
      return LogSentiment.good;
    case GutFeelingRatingLevel.durchschnittlich:
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

String moodLine(
  BuddyMood mood, {
  required String name,
  required int streak,
  required DateTime now,
  required Random rnd,
}) {
  final pool = mood == BuddyMood.sleepy && (now.hour < 5 || now.hour >= 10)
      ? BuddyCopy.sleepyNight
      : BuddyCopy.mood[mood]!;
  return BuddyCopy.fill(BuddyCopy.pick(pool, rnd), name: name, streak: streak);
}
