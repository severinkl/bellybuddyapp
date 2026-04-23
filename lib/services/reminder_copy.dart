enum TimeSlot { morning, midday, evening }

/// Maps a 24-hour clock hour to a [TimeSlot]. Hours 23 and 0–4 wrap into
/// [TimeSlot.evening] — we don't ship a separate "night" pool because the
/// volume doesn't justify it, and evening copy reads fine at 23:30.
TimeSlot timeSlotForHour(int hour) {
  if (hour >= 5 && hour <= 10) return TimeSlot.morning;
  if (hour >= 11 && hour <= 16) return TimeSlot.midday;
  return TimeSlot.evening;
}
