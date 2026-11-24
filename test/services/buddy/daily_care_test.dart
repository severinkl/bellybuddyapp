import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';

void main() {
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
    DateTime t(int h, [int m = 0, int d = 23]) => DateTime(2026, 11, d, h, m);
    CareAction at(int h, CareLog log, [int m = 0]) =>
        nextCareAction(log, t(h, m));

    test('nothing logged: the meal of the time of day', () {
      const none = CareLog();
      expect(at(8, none), CareAction.breakfast);
      expect(at(13, none), CareAction.lunch);
      expect(at(16, none), CareAction.snack);
      expect(at(19, none), CareAction.dinner);
    });

    test('nothing logged at night: Essen eintragen', () {
      expect(at(2, const CareLog()), CareAction.feed);
    });

    test('the lowest meter wins, Klo never does', () {
      final log = CareLog(
        lastMealAt: t(12),
        lastDrinkAt: t(10),
        lastGutFeelingAt: t(8),
      );
      expect(at(13, log), CareAction.drink);
      expect(
        at(
          13,
          CareLog(
            lastMealAt: t(12),
            lastDrinkAt: t(10),
            lastGutFeelingAt: t(8),
            lastToiletAt: t(12, 59),
          ),
        ),
        CareAction.drink,
      );
    });

    test('Bauchgefühl when it is lowest', () {
      // 0.29 vs 0.72 (Trinken) vs 0.83 (Essen).
      final log = CareLog(
        lastMealAt: t(12),
        lastDrinkAt: t(12),
        lastGutFeelingAt: t(8, 0, 22),
      );
      expect(at(13, log), CareAction.gutFeeling);
    });

    test('Essen lowest: the meal of the time of day', () {
      final log = CareLog(
        lastMealAt: t(8),
        lastDrinkAt: t(12, 30),
        lastGutFeelingAt: t(9),
      );
      expect(at(12, log, 45), CareAction.lunch);
    });

    test('ties go Essen, Trinken, Bauchgefühl', () {
      // Trinken and Bauchgefühl both at the floor: Trinken.
      expect(at(14, CareLog(lastMealAt: t(13))), CareAction.drink);
    });

    test('nothing under 35 %: feed', () {
      final log = CareLog(
        lastMealAt: t(12),
        lastDrinkAt: t(12),
        lastGutFeelingAt: t(8),
      );
      expect(at(13, log), CareAction.feed);
    });

    test('a drink for later today is no thirst', () {
      expect(at(13, CareLog(lastDrinkAt: t(18))), isNot(CareAction.drink));
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
