import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';

import '../../helpers/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 23, 13, 0);
  final yesterday = DateTime(2026, 11, 22, 13, 0);

  group('glassesForMl', () {
    test('nothing drunk → 0 glasses', () {
      expect(glassesForMl(0), 0);
    });

    test('250 ml is one glass, 500 ml two', () {
      expect(glassesForMl(250), 1);
      expect(glassesForMl(500), 2);
    });

    test('rounds to the nearest glass', () {
      expect(glassesForMl(600), 2);
      expect(glassesForMl(650), 3);
    });

    test('any drink counts as at least one glass', () {
      expect(glassesForMl(50), 1);
    });
  });

  group('DailyCare.fromEntries', () {
    test('counts only today (local) per need', () {
      final care = DailyCare.fromEntries(
        EntriesState(
          meals: [
            testMealEntry(trackedAt: DateTime(2026, 11, 23, 8)),
            testMealEntry(trackedAt: DateTime(2026, 11, 23, 12)),
            testMealEntry(trackedAt: yesterday),
          ],
          drinks: [
            testDrinkEntry(trackedAt: DateTime(2026, 11, 23, 9)),
            testDrinkEntry(
              trackedAt: DateTime(2026, 11, 23, 10),
              amountMl: 500,
            ),
            testDrinkEntry(trackedAt: yesterday, amountMl: 1000),
          ],
          gutFeelings: [
            testGutFeelingEntry(trackedAt: DateTime(2026, 11, 23, 11)),
          ],
          toiletEntries: [
            testToiletEntry(trackedAt: DateTime(2026, 11, 23, 7)),
            testToiletEntry(trackedAt: DateTime(2026, 11, 23, 12)),
          ],
        ),
        now,
      );

      expect(care.meals, 2);
      expect(care.lastMealAt, DateTime(2026, 11, 23, 12));
      expect(care.glasses, 3); // 250 + 500 ml
      expect(care.gutFeelings, 1);
      expect(care.toilets, 2);
    });

    test('no entries → nothing met', () {
      final care = DailyCare.fromEntries(const EntriesState(), now);
      for (final need in CareNeed.values) {
        expect(care.progress(need), 0, reason: '$need');
        expect(care.isMet(need), isFalse, reason: '$need');
      }
      expect(care.entries, 0);
      expect(care.kindsLogged, 0);
      expect(care.lastLogAt, isNull);
    });

    test("today's entries of every kind, the kinds and the latest one", () {
      final care = DailyCare.fromEntries(
        EntriesState(
          meals: [testMealEntry(trackedAt: DateTime(2026, 11, 23, 8))],
          drinks: [
            testDrinkEntry(trackedAt: DateTime(2026, 11, 23, 9)),
            testDrinkEntry(trackedAt: DateTime(2026, 11, 23, 9, 30)),
            testDrinkEntry(trackedAt: yesterday),
          ],
          toiletEntries: [
            testToiletEntry(trackedAt: DateTime(2026, 11, 23, 12)),
            testToiletEntry(trackedAt: DateTime(2026, 11, 22, 23)),
          ],
        ),
        now,
      );

      expect(care.drinks, 2);
      expect(care.entries, 4);
      expect(care.kindsLogged, 3);
      expect(care.lastLogAt, DateTime(2026, 11, 23, 12));
    });

    test('a drink without volume is an entry but no glass', () {
      final care = DailyCare.fromEntries(
        EntriesState(
          drinks: [
            testDrinkEntry(trackedAt: DateTime(2026, 11, 23, 9), amountMl: 0),
          ],
        ),
        now,
      );

      expect(care.drinks, 1);
      expect(care.glasses, 0);
      expect(care.kindsLogged, 1);
    });

    test('equal when every count and time matches', () {
      expect(
        DailyCare(meals: 1, lastMealAt: now, lastLogAt: now),
        DailyCare(meals: 1, lastMealAt: now, lastLogAt: now),
      );
      expect(const DailyCare(drinks: 1), isNot(const DailyCare(glasses: 1)));
    });
  });

  group('DailyCare progress', () {
    test('food fills in thirds, drink in sixths, capped at 1', () {
      const care = DailyCare(meals: 2, glasses: 9);
      expect(care.progress(CareNeed.food), closeTo(2 / 3, 1e-9));
      expect(care.progress(CareNeed.drink), 1);
      expect(care.isMet(CareNeed.drink), isTrue);
    });

    test('Bauchgefühl is met with one entry', () {
      expect(
        const DailyCare(gutFeelings: 1).isMet(CareNeed.gutFeeling),
        isTrue,
      );
    });

    test('Klo has no goal: any log fills it', () {
      expect(DailyCare.goalFor(CareNeed.toilet), isNull);
      expect(const DailyCare(toilets: 1).progress(CareNeed.toilet), 1);
      expect(const DailyCare().progress(CareNeed.toilet), 0);
    });
  });

  group('mealSlotAt', () {
    test('Frühstück until 10:30, Mittag until 15:00, Snack until 17:00, '
        'then Abendessen', () {
      expect(mealSlotAt(DateTime(2026, 11, 23, 6)), CareAction.breakfast);
      expect(mealSlotAt(DateTime(2026, 11, 23, 10, 29)), CareAction.breakfast);
      expect(mealSlotAt(DateTime(2026, 11, 23, 10, 30)), CareAction.lunch);
      expect(mealSlotAt(DateTime(2026, 11, 23, 14, 59)), CareAction.lunch);
      expect(mealSlotAt(DateTime(2026, 11, 23, 15)), CareAction.snack);
      expect(mealSlotAt(DateTime(2026, 11, 23, 16, 59)), CareAction.snack);
      expect(mealSlotAt(DateTime(2026, 11, 23, 17)), CareAction.dinner);
      expect(mealSlotAt(DateTime(2026, 11, 23, 23)), CareAction.dinner);
    });

    test('none before the day starts (05:00): no breakfast at night', () {
      expect(mealSlotAt(DateTime(2026, 11, 23, 0, 30)), isNull);
      expect(mealSlotAt(DateTime(2026, 11, 23, 4, 59)), isNull);
      expect(mealSlotAt(DateTime(2026, 11, 23, 5)), CareAction.breakfast);
    });
  });

  group('DayParts', () {
    test('by day from 05:00 until 22:00', () {
      bool at(int h, [int m = 0]) =>
          DayParts.isDay(DateTime(2026, 11, 23, h, m));
      expect(at(4, 59), isFalse);
      expect(at(5), isTrue);
      expect(at(21, 59), isTrue);
      expect(at(22), isFalse);
    });
  });

  group('nextCareAction', () {
    CareAction at(int h, DailyCare care, [int m = 0]) =>
        nextCareAction(care, DateTime(2026, 11, 23, h, m));
    DateTime t(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);

    test('the meal the time of day asks for comes first', () {
      expect(at(8, const DailyCare()), CareAction.breakfast);
      expect(at(13, DailyCare(meals: 1, lastMealAt: t(8))), CareAction.lunch);
      expect(at(16, DailyCare(meals: 1, lastMealAt: t(8))), CareAction.snack);
      expect(at(19, DailyCare(meals: 2, lastMealAt: t(12))), CareAction.dinner);
    });

    test('a late-night meal is no breakfast: at 08:00 he still asks', () {
      expect(
        at(8, DailyCare(meals: 1, lastMealAt: t(1))),
        CareAction.breakfast,
      );
      expect(
        at(8, DailyCare(meals: 1, lastMealAt: t(5), glasses: 1)),
        CareAction.drink,
      );
    });

    test('before 05:00 no meal is suggested: the next need instead', () {
      expect(at(2, const DailyCare()), CareAction.drink);
      expect(
        at(4, const DailyCare(glasses: 6, gutFeelings: 1)),
        CareAction.feed,
      );
    });

    test('nothing eaten by noon → the lunch slot', () {
      expect(at(13, const DailyCare()), CareAction.lunch);
    });

    test('a skipped breakfast is not asked for once lunch is logged', () {
      expect(
        at(13, DailyCare(meals: 1, lastMealAt: t(12, 30), glasses: 2)),
        CareAction.drink,
      );
    });

    test('a meal in this slot → Trinken while under the goal', () {
      expect(
        at(13, DailyCare(meals: 2, lastMealAt: t(12), glasses: 3)),
        CareAction.drink,
      );
      expect(
        at(16, DailyCare(meals: 2, lastMealAt: t(12), glasses: 3)),
        CareAction.drink,
      );
    });

    test('drinks done too → Bauchgefühl if not logged', () {
      expect(
        at(13, DailyCare(meals: 2, lastMealAt: t(12), glasses: 6)),
        CareAction.gutFeeling,
      );
    });

    test('everything for now done → Füttern', () {
      expect(
        at(
          13,
          DailyCare(meals: 2, lastMealAt: t(12), glasses: 6, gutFeelings: 1),
        ),
        CareAction.feed,
      );
      expect(
        at(
          20,
          DailyCare(meals: 3, lastMealAt: t(19), glasses: 6, gutFeelings: 1),
        ),
        CareAction.feed,
      );
    });

    test('three meals logged → no more meal suggestions today', () {
      expect(
        at(20, DailyCare(meals: 3, lastMealAt: t(15), glasses: 1)),
        CareAction.drink,
      );
    });

    test('Klo never drives the suggestion', () {
      expect(
        at(
          13,
          DailyCare(meals: 2, lastMealAt: t(12), glasses: 6, gutFeelings: 1),
        ),
        CareAction.feed,
      );
    });
  });

  group('CareAction.need', () {
    test('meal actions are food, the others their need, Füttern none', () {
      for (final a in [
        CareAction.breakfast,
        CareAction.lunch,
        CareAction.snack,
        CareAction.dinner,
      ]) {
        expect(a.need, CareNeed.food, reason: '$a');
      }
      expect(CareAction.drink.need, CareNeed.drink);
      expect(CareAction.gutFeeling.need, CareNeed.gutFeeling);
      expect(CareAction.feed.need, isNull);
    });
  });
}
