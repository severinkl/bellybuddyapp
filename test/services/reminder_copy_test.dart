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
}
