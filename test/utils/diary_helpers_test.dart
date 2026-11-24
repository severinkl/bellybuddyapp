import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/diary_helpers.dart';
import 'package:belly_buddy/models/diary_entry.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/utils/drink_helpers.dart';

import '../helpers/fixtures.dart';

void main() {
  group('DiaryHelpers.buildEntries', () {
    test('empty result returns empty list', () {
      const result = EntryQueryResult(
        meals: [],
        toiletEntries: [],
        gutFeelings: [],
        drinks: [],
      );
      expect(DiaryHelpers.buildEntries(result), isEmpty);
    });

    test('builds meal entries with Zutaten subtitle', () {
      final result = EntryQueryResult(
        meals: [
          MealEntry(
            id: 'm1',
            trackedAt: DateTime(2026, 1, 1, 12),
            title: 'Mittagessen',
            ingredients: ['Reis', 'Hähnchen', 'Soße'],
          ),
        ],
        toiletEntries: [],
        gutFeelings: [],
        drinks: [],
      );
      final entries = DiaryHelpers.buildEntries(result);
      expect(entries.length, 1);
      expect(entries.first.type, DiaryEntryType.meal);
      expect(entries.first.subtitle, '3 Zutaten');
    });

    test('builds toilet entries with stool type description', () {
      final result = EntryQueryResult(
        meals: [],
        toiletEntries: [
          ToiletEntry(
            id: 't1',
            trackedAt: DateTime(2026, 1, 1, 10),
            stoolType: 4,
          ),
        ],
        gutFeelings: [],
        drinks: [],
      );
      final entries = DiaryHelpers.buildEntries(result);
      expect(entries.length, 1);
      expect(entries.first.type, DiaryEntryType.toilet);
      expect(entries.first.title, 'Klo');
    });

    test('builds gut feeling entries', () {
      final result = EntryQueryResult(
        meals: [],
        toiletEntries: [],
        gutFeelings: [
          GutFeelingEntry(
            id: 'g1',
            trackedAt: DateTime(2026, 1, 1, 9),
            bloating: 1,
            gas: 1,
            cramps: 1,
            fullness: 1,
          ),
        ],
        drinks: [],
      );
      final entries = DiaryHelpers.buildEntries(result);
      expect(entries.length, 1);
      expect(entries.first.type, DiaryEntryType.gutFeeling);
      expect(entries.first.title, 'Bauchgefühl');
      expect(entries.first.subtitle, 'Alles gut');
    });

    test('builds drink entries with ml subtitle', () {
      final result = EntryQueryResult(
        meals: [],
        toiletEntries: [],
        gutFeelings: [],
        drinks: [
          DrinkEntry(
            id: 'd1',
            trackedAt: DateTime(2026, 1, 1, 8),
            drinkId: 'dk1',
            drinkName: 'Wasser',
            amountMl: 500,
          ),
        ],
      );
      final entries = DiaryHelpers.buildEntries(result);
      expect(entries.length, 1);
      expect(entries.first.type, DiaryEntryType.drink);
      expect(entries.first.title, 'Wasser');
      expect(entries.first.subtitle, '500 ml');
    });

    test('sorts all entries by trackedAt descending', () {
      final result = EntryQueryResult(
        meals: [
          MealEntry(
            id: 'm1',
            trackedAt: DateTime(2026, 1, 1, 12),
            title: 'Lunch',
          ),
        ],
        toiletEntries: [],
        gutFeelings: [
          GutFeelingEntry(
            id: 'g1',
            trackedAt: DateTime(2026, 1, 1, 18),
            bloating: 1,
            gas: 1,
            cramps: 1,
            fullness: 1,
          ),
        ],
        drinks: [
          DrinkEntry(
            id: 'd1',
            trackedAt: DateTime(2026, 1, 1, 8),
            drinkId: 'dk1',
            drinkName: 'Wasser',
            amountMl: 250,
          ),
        ],
      );
      final entries = DiaryHelpers.buildEntries(result);
      expect(entries.length, 3);
      expect(entries[0].id, 'g1'); // 18:00
      expect(entries[1].id, 'm1'); // 12:00
      expect(entries[2].id, 'd1'); // 08:00
    });
  });

  group('DiaryHelpers.dayTotals', () {
    String? totals({
      List<MealEntry> meals = const [],
      List<DrinkEntry> drinks = const [],
      List<GutFeelingEntry> gutFeelings = const [],
      List<ToiletEntry> toiletEntries = const [],
    }) => DiaryHelpers.dayTotals(
      DiaryHelpers.buildEntries(
        testEntryQueryResult(
          meals: meals,
          drinks: drinks,
          gutFeelings: gutFeelings,
          toiletEntries: toiletEntries,
        ),
      ),
    );

    DrinkEntry drink(int ml) => testDrinkEntry(id: 'd$ml', amountMl: ml);

    test('lists meals, drinks and Bauchgefühl in order', () {
      expect(
        totals(
          meals: [
            testMealEntry(id: 'm1'),
            testMealEntry(id: 'm2'),
          ],
          drinks: [drink(250), drink(1250)],
          gutFeelings: [testGutFeelingEntry()],
        ),
        '2× Essen · 1,5 L getrunken · 1× Bauchgefühl',
      );
    });

    test('writes the amount as the drink tracker does', () {
      for (final ml in [750, 2000, 1250]) {
        expect(
          totals(drinks: [drink(ml)]),
          '${DrinkHelpers.formatAmount(ml)} getrunken',
        );
      }
      expect(totals(drinks: [drink(2000)]), '2 L getrunken');
    });

    test('only one Klo', () {
      expect(totals(toiletEntries: [testToiletEntry()]), '1× Klo');
    });

    test('nothing to count is null: no entries, or only 0 ml drunk', () {
      expect(totals(), isNull);
      expect(totals(drinks: [drink(0)]), isNull);
    });
  });
}
