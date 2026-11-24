import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/drink_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/toilet_entry.dart';

/// `tracked_at` exactly as PostgREST sends it: the user's wall clock in the
/// UTC slot. `created_at` is a real instant (server `now()`).
const _wire = '2026-11-24T23:30:00+00:00';
const _createdWire = '2026-11-24T22:30:05.120+00:00';
final _wallClock = DateTime(2026, 11, 24, 23, 30);

void main() {
  group('every entry model reads tracked_at as wall-clock local time', () {
    final parsed = <String, DateTime>{
      'meal': MealEntry.fromJson({
        'id': 'm',
        'title': 'Abendessen',
        'tracked_at': _wire,
      }).trackedAt,
      'drink (fromJson)': DrinkEntry.fromJson({
        'id': 'd',
        'drink_id': 'water',
        'amount_ml': 250,
        'tracked_at': _wire,
      }).trackedAt,
      'drink (fromDbRow)': DrinkEntry.fromDbRow({
        'id': 'd',
        'drink_id': 'water',
        'amount_ml': 250,
        'tracked_at': _wire,
        'drinks': {'name': 'Wasser'},
      }).trackedAt,
      'gut feeling': GutFeelingEntry.fromJson({
        'id': 'g',
        'bloating': 0,
        'gas': 0,
        'cramps': 0,
        'fullness': 0,
        'tracked_at': _wire,
      }).trackedAt,
      'toilet': ToiletEntry.fromJson({
        'id': 't',
        'stool_type': 3,
        'tracked_at': _wire,
      }).trackedAt,
    };

    for (final MapEntry(key: kind, value: trackedAt) in parsed.entries) {
      test(kind, () {
        expect(trackedAt, _wallClock);
        expect(trackedAt.isUtc, isFalse);
      });
    }
  });

  group('every entry model writes tracked_at as the wall clock, marked Z', () {
    const expected = '2026-11-24T23:30:00.000Z';
    final written = <String, Object?>{
      'meal': MealEntry(
        id: 'm',
        title: 'Abendessen',
        trackedAt: _wallClock,
      ).toJson()['tracked_at'],
      'drink': DrinkEntry(
        id: 'd',
        drinkId: 'water',
        amountMl: 250,
        trackedAt: _wallClock,
      ).toInsertJson()['tracked_at'],
      'gut feeling': GutFeelingEntry(
        id: 'g',
        bloating: 0,
        gas: 0,
        cramps: 0,
        fullness: 0,
        trackedAt: _wallClock,
      ).toJson()['tracked_at'],
      'toilet': ToiletEntry(
        id: 't',
        stoolType: 3,
        trackedAt: _wallClock,
      ).toJson()['tracked_at'],
    };

    for (final MapEntry(key: kind, value: value) in written.entries) {
      test(kind, () => expect(value, expected));
    }
  });

  test('an edit writes back exactly the value it read', () {
    final meal = MealEntry.fromJson({
      'id': 'm',
      'title': 'Abendessen',
      'tracked_at': _wire,
    });

    expect(
      DateTime.parse(meal.toJson()['tracked_at'] as String),
      DateTime.parse(_wire),
    );
  });

  test('created_at stays a real instant', () {
    final meal = MealEntry.fromJson({
      'id': 'm',
      'title': 'Abendessen',
      'tracked_at': _wire,
      'created_at': _createdWire,
    });

    expect(meal.createdAt, DateTime.utc(2026, 11, 24, 22, 30, 5, 120));
    expect(meal.createdAt!.isUtc, isTrue);
  });
}
