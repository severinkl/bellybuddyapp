import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/drink_entry.dart';

void main() {
  group('DrinkEntry', () {
    final sampleEntry = DrinkEntry(
      id: 'abc',
      trackedAt: DateTime(2026, 3, 13, 14, 30),
      drinkId: 'drink-1',
      amountMl: 250,
      notes: 'warm',
    );

    test('toInsertJson includes tracked_at, drink_id, amount_ml, notes', () {
      final json = sampleEntry.toInsertJson();
      expect(json['tracked_at'], sampleEntry.trackedAt.toIso8601String());
      expect(json['drink_id'], 'drink-1');
      expect(json['amount_ml'], 250);
      expect(json['notes'], 'warm');
    });

    test('toInsertJson excludes id, user_id, created_at, drinkName', () {
      final json = sampleEntry.toInsertJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('drinkName'), isFalse);
      expect(json.containsKey('drink_name'), isFalse);
    });

    test('fromDbRow extracts drink name from nested drinks map', () {
      final entry = DrinkEntry.fromDbRow({
        'id': 'abc',
        'user_id': 'user-1',
        'tracked_at': '2026-03-13T14:30:00.000',
        'drink_id': 'drink-1',
        'amount_ml': 500,
        'notes': null,
        'drinks': {'name': 'Wasser'},
      });
      expect(entry.drinkName, 'Wasser');
    });

    test('fromDbRow with missing drinks uses default name', () {
      final entry = DrinkEntry.fromDbRow({
        'id': 'abc',
        'tracked_at': '2026-03-13T14:30:00.000',
        'drink_id': 'drink-1',
        'amount_ml': 250,
        'notes': null,
        'drinks': null,
      });
      expect(entry.drinkName, 'Unbekanntes Getränk');
    });

    test('fromDbRow parses DateTime from string', () {
      final entry = DrinkEntry.fromDbRow({
        'id': 'abc',
        'tracked_at': '2026-03-13T14:30:00.000',
        'drink_id': 'drink-1',
        'amount_ml': 250,
        'notes': null,
      });
      expect(entry.trackedAt, DateTime(2026, 3, 13, 14, 30));
    });

    test('fromDbRow with null notes', () {
      final entry = DrinkEntry.fromDbRow({
        'id': 'abc',
        'tracked_at': '2026-03-13T14:30:00.000',
        'drink_id': 'drink-1',
        'amount_ml': 250,
        'notes': null,
      });
      expect(entry.notes, isNull);
    });
  });
}
