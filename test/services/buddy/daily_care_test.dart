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
      expect(mealSlotAt(DateTime(2026, 11, 23, 6)), MealSlot.breakfast);
      expect(mealSlotAt(DateTime(2026, 11, 23, 10, 29)), MealSlot.breakfast);
      expect(mealSlotAt(DateTime(2026, 11, 23, 10, 30)), MealSlot.lunch);
      expect(mealSlotAt(DateTime(2026, 11, 23, 14, 59)), MealSlot.lunch);
      expect(mealSlotAt(DateTime(2026, 11, 23, 15)), MealSlot.snack);
      expect(mealSlotAt(DateTime(2026, 11, 23, 16, 59)), MealSlot.snack);
      expect(mealSlotAt(DateTime(2026, 11, 23, 17)), MealSlot.dinner);
      expect(mealSlotAt(DateTime(2026, 11, 23, 23)), MealSlot.dinner);
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
