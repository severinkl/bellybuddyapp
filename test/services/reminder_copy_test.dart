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
}
