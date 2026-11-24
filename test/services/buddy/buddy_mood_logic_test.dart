import 'dart:math';

import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy_actions.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixtures.dart';

GutFeelingEntry _gut(int v) =>
    testGutFeelingEntry(bloating: v, gas: v, cramps: v, fullness: v);

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 22, h, m);

  group('deriveBuddyMood', () {
    test('nothing today: sleepy until 10:00, then hungry', () {
      expect(deriveBuddyMood(const CareLog(), at(9, 59)), BuddyMood.sleepy);
      expect(deriveBuddyMood(const CareLog(), at(10)), BuddyMood.hungry);
    });

    test('every meter at 70 % or more -> energetic', () {
      final log = CareLog(
        lastMealAt: at(13, 30),
        lastDrinkAt: at(13, 30),
        lastGutFeelingAt: at(8),
      );
      expect(deriveBuddyMood(log, at(14)), BuddyMood.energetic);
    });

    test('the lowest at 35 % or more -> happy; under it by day -> hungry, '
        'late -> sleepy', () {
      final log = CareLog(
        lastMealAt: at(13),
        lastDrinkAt: at(12),
        lastGutFeelingAt: at(8),
      );
      expect(deriveBuddyMood(log, at(14)), BuddyMood.happy);

      final thirsty = CareLog(
        lastMealAt: at(13),
        lastDrinkAt: at(10),
        lastGutFeelingAt: at(8),
      );
      expect(deriveBuddyMood(thirsty, at(14)), BuddyMood.hungry);
      expect(deriveBuddyMood(thirsty, at(22, 30)), BuddyMood.sleepy);
    });

    test('only Klo this morning -> still sleepy', () {
      expect(
        deriveBuddyMood(CareLog(lastToiletAt: at(7)), at(8)),
        BuddyMood.sleepy,
      );
    });

    test("yesterday's late drink still counts", () {
      final log = CareLog(
        lastDrinkAt: DateTime(2026, 11, 21, 21, 30),
        lastMealAt: at(7),
        lastGutFeelingAt: at(7, 15),
      );
      expect(deriveBuddyMood(log, at(7, 30)), BuddyMood.energetic);
    });
  });

  group('careNeedOf', () {
    test('each entry kind fills its need', () {
      expect(careNeedOf(EntryKind.meal), CareNeed.food);
      expect(careNeedOf(EntryKind.drink), CareNeed.drink);
      expect(careNeedOf(EntryKind.gutFeeling), CareNeed.gutFeeling);
      expect(careNeedOf(EntryKind.toilet), CareNeed.toilet);
    });
  });

  group('sentiment', () {
    test('gut feeling levels', () {
      expect(sentimentForGutFeeling(_gut(1)), LogSentiment.good);
      expect(sentimentForGutFeeling(_gut(2)), LogSentiment.good);
      expect(sentimentForGutFeeling(_gut(3)), LogSentiment.neutral);
      expect(sentimentForGutFeeling(_gut(5)), LogSentiment.bad);
    });

    test('gut feeling follows the worst symptom, not the average', () {
      final hardDay = testGutFeelingEntry(
        bloating: 1,
        gas: 1,
        cramps: 5,
        fullness: 5,
      );
      expect(sentimentForGutFeeling(hardDay), LogSentiment.bad);
      final reaction = reactionFor(
        EntryKind.gutFeeling,
        sentimentForGutFeeling(hardDay),
        name: 'Bubu',
        rnd: Random(1),
      );
      expect(reaction.action, BuddyAction.hug);
      expect(reaction.moodAfter, BuddyMood.empathetic);

      expect(
        sentimentForGutFeeling(
          testGutFeelingEntry(bloating: 3, gas: 1, cramps: 1, fullness: 1),
        ),
        LogSentiment.neutral,
      );
    });

    test('a bad mood alone keeps the gut feeling good', () {
      final calmGut = testGutFeelingEntry(
        bloating: 1,
        gas: 1,
        cramps: 1,
        fullness: 1,
      ).copyWith(stress: 5, happiness: 5, energy: 5, focus: 5, bodyFeel: 5);
      expect(sentimentForGutFeeling(calmGut), LogSentiment.good);
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
