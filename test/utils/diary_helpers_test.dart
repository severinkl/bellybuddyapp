import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/diary_helpers.dart';
import 'package:belly_buddy/models/diary_entry.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/toilet_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/services/entry_query_service.dart';

void main() {
  group('DiaryHelpers.buildEntries', () {
    test('empty result returns empty list', () {
      final result = EntryQueryResult(
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
      expect(entries.first.title, 'Toilettengang');
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
}
