import 'package:freezed_annotation/freezed_annotation.dart';

// Entry times (`tracked_at`) are the user's wall-clock time, stored in the
// UTC slot of the `timestamptz` column: a meal at 23:30 local is stored as
// 23:30Z and PostgREST sends it back as `…T23:30:00+00:00`. This has been
// the app's convention since its first release, and the server reads it the
// same way. They are not instants. `created_at` is, and is parsed normally.
//
// Every `tracked_at` is read with [wallClockFromWire] and written (values
// and query bounds) with [wallClockToWire], so the app works with plain
// local [DateTime]s: compare them with `DateTime.now()`, take their day,
// never `toLocal()`/`toUtc()` them.

/// A `tracked_at` value from the database as the local [DateTime] the user
/// logged: the parsed value's fields, without converting them.
DateTime wallClockFromWire(String value) {
  final p = DateTime.parse(value);
  return DateTime(
    p.year,
    p.month,
    p.day,
    p.hour,
    p.minute,
    p.second,
    p.millisecond,
    p.microsecond,
  );
}

/// [time]'s local wall clock for a `tracked_at` value or bound, in the UTC
/// slot (`…Z`). A UTC [time] is an instant and is sent as its local wall
/// clock.
String wallClockToWire(DateTime time) {
  final l = time.isUtc ? time.toLocal() : time;
  return DateTime.utc(
    l.year,
    l.month,
    l.day,
    l.hour,
    l.minute,
    l.second,
    l.millisecond,
    l.microsecond,
  ).toIso8601String();
}

/// JSON converter for an entry model's `trackedAt`; see [wallClockFromWire]
/// and [wallClockToWire].
class WallClockConverter implements JsonConverter<DateTime, String> {
  const WallClockConverter();

  @override
  DateTime fromJson(String json) => wallClockFromWire(json);

  @override
  String toJson(DateTime object) => wallClockToWire(object);
}
