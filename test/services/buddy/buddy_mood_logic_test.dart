import 'dart:math';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/buddy_actions.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixtures.dart';

GutFeelingEntry _gut(int v) =>
    testGutFeelingEntry(bloating: v, gas: v, cramps: v, fullness: v);

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 22, h, m);

  group('deriveBuddyMood', () {
    test('no logs before 10:00 -> sleepy (boundary 09:59 vs 10:00)', () {
      expect(deriveBuddyMood(const TodayCare(), at(9, 59)), BuddyMood.sleepy);
      expect(deriveBuddyMood(const TodayCare(), at(10)), BuddyMood.hungry);
    });

    test('three kinds -> energetic', () {
      final care = TodayCare(
        count: 3,
        kinds: {EntryKind.meal, EntryKind.drink, EntryKind.toilet},
        lastLogAt: at(8),
      );
      expect(deriveBuddyMood(care, at(20)), BuddyMood.energetic);
    });

    test('recent log within 5h -> happy (4h59 vs 5h01)', () {
      final care = TodayCare(
        count: 1,
        kinds: {EntryKind.meal},
        lastLogAt: at(8),
      );
      expect(deriveBuddyMood(care, at(12, 59)), BuddyMood.happy);
      expect(deriveBuddyMood(care, at(13, 1)), BuddyMood.hungry);
    });

    test('late night without recent log -> sleepy', () {
      final care = TodayCare(
        count: 1,
        kinds: {EntryKind.meal},
        lastLogAt: at(8),
      );
      expect(deriveBuddyMood(care, at(22)), BuddyMood.sleepy);
      expect(deriveBuddyMood(const TodayCare(), at(23)), BuddyMood.sleepy);
    });
  });

  group('TodayCare.fromEntries', () {
    test('only counts today and ignores yesterday', () {
      final now = at(15);
      final s = EntriesState(
        meals: [
          testMealEntry(trackedAt: at(8)),
          testMealEntry(
            id: 'old',
            trackedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        toiletEntries: [testToiletEntry(trackedAt: at(12))],
        gutFeelings: const [],
        drinks: [
          testDrinkEntry(trackedAt: now.subtract(const Duration(days: 1))),
        ],
      );
      final care = TodayCare.fromEntries(s, now);
      expect(care.count, 2);
      expect(care.kinds, {EntryKind.meal, EntryKind.toilet});
      expect(care.lastLogAt, at(12));
    });

    test('empty state', () {
      final care = TodayCare.fromEntries(const EntriesState(), at(9));
      expect(care.count, 0);
      expect(care.lastLogAt, isNull);
    });
  });

  group('sentiment', () {
    test('gut feeling levels', () {
      expect(sentimentForGutFeeling(_gut(1)), LogSentiment.good);
      expect(sentimentForGutFeeling(_gut(2)), LogSentiment.good);
      expect(sentimentForGutFeeling(_gut(3)), LogSentiment.neutral);
      expect(sentimentForGutFeeling(_gut(5)), LogSentiment.bad);
    });

    test('stool types 1-5', () {
      LogSentiment s(int t) =>
          sentimentForToilet(testToiletEntry(stoolType: t));
      expect(s(1), LogSentiment.bad);
      expect(s(2), LogSentiment.neutral);
      expect(s(3), LogSentiment.good);
      expect(s(4), LogSentiment.neutral);
      expect(s(5), LogSentiment.bad);
    });
  });

  group('reactionFor', () {
    final rnd = Random(1);
    BuddyReaction r(EntryKind k, LogSentiment s) =>
        reactionFor(k, s, name: 'Bubu', rnd: rnd);

    test('every kind x sentiment has a non-empty line', () {
      for (final k in EntryKind.values) {
        for (final s in LogSentiment.values) {
          final reaction = r(k, s);
          expect(reaction.line, isNotEmpty);
          expect(reaction.line, isNot(contains('{')));
        }
      }
    });

    test('actions', () {
      expect(r(EntryKind.meal, LogSentiment.bad).action, BuddyAction.eat);
      expect(r(EntryKind.drink, LogSentiment.good).action, BuddyAction.drink);
      expect(r(EntryKind.toilet, LogSentiment.good).action, BuddyAction.relief);
      expect(
        r(EntryKind.toilet, LogSentiment.neutral).action,
        BuddyAction.relief,
      );
      final tb = r(EntryKind.toilet, LogSentiment.bad);
      expect(tb.action, BuddyAction.hug);
      expect(tb.moodAfter, BuddyMood.empathetic);
      expect(
        r(EntryKind.gutFeeling, LogSentiment.good).action,
        BuddyAction.celebrate,
      );
      expect(
        r(EntryKind.gutFeeling, LogSentiment.neutral).action,
        BuddyAction.nodYes,
      );
      final gb = r(EntryKind.gutFeeling, LogSentiment.bad);
      expect(gb.action, BuddyAction.hug);
      expect(gb.moodAfter, BuddyMood.empathetic);
    });
  });

  group('moodLine', () {
    test('every mood has a line without leftover placeholders', () {
      for (final m in BuddyMood.values) {
        for (var i = 0; i < 20; i++) {
          final line = moodLine(
            m,
            name: 'Bubu',
            streak: 4,
            now: at(9),
            rnd: Random(i),
          );
          expect(line, isNotEmpty);
          expect(line, isNot(contains('{')));
        }
      }
    });

    test('quotes the streak only from 2 days on', () {
      Set<String> lines(BuddyMood m, int streak) => {
        for (var i = 0; i < 40; i++)
          moodLine(
            m,
            name: 'Bubu',
            streak: streak,
            now: at(14),
            rnd: Random(i),
          ),
      };
      for (final m in [BuddyMood.happy, BuddyMood.energetic]) {
        for (final streak in [0, 1]) {
          final pool = lines(m, streak);
          expect(pool, isNotEmpty);
          expect(pool.any((l) => l.contains('$streak Tage')), isFalse);
        }
        expect(lines(m, 2).any((l) => l.contains('2 Tage')), isTrue);
      }
    });

    test('sleepy splits morning and night lines', () {
      Set<String> lines(DateTime now) => {
        for (var i = 0; i < 40; i++)
          moodLine(
            BuddyMood.sleepy,
            name: 'Bubu',
            streak: 1,
            now: now,
            rnd: Random(i),
          ),
      };
      final morning = lines(at(8));
      final night = lines(at(23));
      expect(morning.any((l) => l.contains('Guten Morgen')), isTrue);
      expect(morning.any((l) => l.contains('Gute Nacht')), isFalse);
      expect(night.any((l) => l.contains('Gute Nacht')), isTrue);
      expect(night.any((l) => l.contains('Guten Morgen')), isFalse);
      expect(night.every((l) => !l.contains('{')), isTrue);
      expect(lines(at(2)).any((l) => l.contains('Guten Morgen')), isFalse);
      expect(lines(at(2)).any((l) => l.contains('Gute Nacht')), isTrue);
      expect(lines(at(5)).any((l) => l.contains('Guten Morgen')), isTrue);
    });
  });
}
