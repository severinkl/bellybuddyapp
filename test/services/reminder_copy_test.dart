import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/reminder_copy.dart';

void main() {
  group('timeSlotForHour', () {
    test('maps boundary hours correctly (night wraps into evening)', () {
      expect(timeSlotForHour(0), TimeSlot.evening);
      expect(timeSlotForHour(4), TimeSlot.evening);
      expect(timeSlotForHour(5), TimeSlot.morning);
      expect(timeSlotForHour(10), TimeSlot.morning);
      expect(timeSlotForHour(11), TimeSlot.midday);
      expect(timeSlotForHour(16), TimeSlot.midday);
      expect(timeSlotForHour(17), TimeSlot.evening);
      expect(timeSlotForHour(22), TimeSlot.evening);
      expect(timeSlotForHour(23), TimeSlot.evening);
    });
  });

  group('ReminderCopy.pickMealBody', () {
    test('morning hour returns a line from the morning meal pool', () {
      final body = ReminderCopy.pickMealBody(7, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.morning]!, contains(body));
    });

    test('midday hour returns a line from the midday meal pool', () {
      final body = ReminderCopy.pickMealBody(13, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.midday]!, contains(body));
    });

    test('evening hour returns a line from the evening meal pool', () {
      final body = ReminderCopy.pickMealBody(20, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.evening]!, contains(body));
    });

    test('night hour (23) draws from the evening meal pool', () {
      final body = ReminderCopy.pickMealBody(23, Random(42));
      expect(ReminderCopy.mealPools[TimeSlot.evening]!, contains(body));
    });
  });

  group('ReminderCopy.pickMoodBody', () {
    test('morning hour returns a line from the morning mood pool', () {
      final body = ReminderCopy.pickMoodBody(7, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.morning]!, contains(body));
    });

    test('evening hour returns a line from the evening mood pool', () {
      final body = ReminderCopy.pickMoodBody(20, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.evening]!, contains(body));
    });

    test('midday hour falls back to the evening mood pool', () {
      final body = ReminderCopy.pickMoodBody(13, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.evening]!, contains(body));
    });

    test('night hour (23) draws from the evening mood pool', () {
      final body = ReminderCopy.pickMoodBody(23, Random(42));
      expect(ReminderCopy.moodPools[TimeSlot.evening]!, contains(body));
    });
  });

  group('previews', () {
    test('a fixed Buddy-voiced line from the real pools, with his name', () {
      final meal = ReminderCopy.previewMealBody(18, 'Bauchi');
      expect(meal, '🍲 Bauchi ist gespannt auf dein Abendessen!');
      expect(ReminderCopy.previewMealBody(18, 'Bauchi'), meal);

      final mood = ReminderCopy.previewMoodBody(20, 'Bauchi');
      expect(mood, '🤷 Bauchi fragt: Wie war dein Bauchgefühl heute?');
      // Midday has no mood pool: the evening one is used.
      expect(ReminderCopy.previewMoodBody(13, 'Bauchi'), mood);
    });
  });

  test('says „Abendessen", not the northern „Abendbrot"', () {
    final pools = [
      ReminderCopy.mealPools,
      ReminderCopy.buddyMealPools,
      ReminderCopy.moodPools,
      ReminderCopy.buddyMoodPools,
    ];
    for (final pool in pools) {
      for (final line in pool.values.expand((l) => l)) {
        expect(line, isNot(contains('Abendbrot')));
      }
    }
  });

  group('pool integrity', () {
    test('every meal pool is non-empty', () {
      for (final entry in ReminderCopy.mealPools.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'meal pool for ${entry.key} is empty',
        );
      }
    });

    test('every mood pool is non-empty', () {
      for (final entry in ReminderCopy.moodPools.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'mood pool for ${entry.key} is empty',
        );
      }
    });

    test('no meal line appears in more than one slot', () {
      final all = ReminderCopy.mealPools.values.expand((p) => p).toList();
      expect(all.toSet().length, all.length);
    });

    test('no mood line appears in more than one slot', () {
      final all = ReminderCopy.moodPools.values.expand((p) => p).toList();
      expect(all.toSet().length, all.length);
    });
  });

  group('Buddy pools', () {
    test('meal: >=4 per slot, name substituted, no placeholders', () {
      for (final slot in TimeSlot.values) {
        expect(
          ReminderCopy.buddyMealPools[slot]!.length,
          greaterThanOrEqualTo(4),
        );
      }
      for (var hour = 0; hour < 24; hour++) {
        for (var seed = 0; seed < 20; seed++) {
          final body = ReminderCopy.pickMealBody(
            hour,
            Random(seed),
            buddyName: 'Pünktchen',
          );
          expect(body, contains('Pünktchen'));
          expect(body, isNot(contains('{')));
          expect(body, isNot(matches(RegExp(r'\d+ Tage'))));
        }
      }
    });

    test('mood: >=4 per slot, name substituted, midday falls back', () {
      for (final pool in ReminderCopy.buddyMoodPools.values) {
        expect(pool.length, greaterThanOrEqualTo(4));
      }
      for (var hour = 0; hour < 24; hour++) {
        for (var seed = 0; seed < 20; seed++) {
          final body = ReminderCopy.pickMoodBody(
            hour,
            Random(seed),
            buddyName: 'Pünktchen',
          );
          expect(body, contains('Pünktchen'));
          expect(body, isNot(contains('{')));
        }
      }
    });

    test('without a name the classic pools are used', () {
      final meal = ReminderCopy.pickMealBody(12, Random(1));
      expect(ReminderCopy.mealPools[TimeSlot.midday], contains(meal));
      final mood = ReminderCopy.pickMoodBody(8, Random(1));
      expect(ReminderCopy.moodPools[TimeSlot.morning], contains(mood));
    });
  });
}
