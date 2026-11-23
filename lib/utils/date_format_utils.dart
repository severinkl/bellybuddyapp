import 'package:intl/intl.dart';

/// Returns the start of the given day (midnight).
DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns the start of the next day (exclusive end bound for date queries).
DateTime endOfDay(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day).add(const Duration(days: 1));

/// The day [days] calendar days after [d]'s date (before it when negative),
/// at midnight. Calendar arithmetic, so it never drifts across DST switches
/// the way adding `Duration(days: …)` does.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// The Monday of [d]'s week, at midnight.
DateTime mondayOf(DateTime d) => addDays(d, 1 - d.weekday);

/// The ISO 8601 week number of [d]'s date (1–53): weeks start on Monday,
/// and a week belongs to the year its Thursday falls in. Pass a local time
/// for the user's week.
int isoWeekOf(DateTime d) {
  final thursday = addDays(d, DateTime.thursday - d.weekday);
  // Counted in UTC, so a DST switch never shortens a day.
  final dayOfYear = DateTime.utc(
    thursday.year,
    thursday.month,
    thursday.day,
  ).difference(DateTime.utc(thursday.year)).inDays;
  return dayOfYear ~/ 7 + 1;
}

/// The German weekday names, Monday first (index: `weekday - 1`).
const kWeekdayNames = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Their two-letter short forms, Monday first („Mo" … „So").
final List<String> kWeekdayShortNames = List.unmodifiable([
  for (final name in kWeekdayNames) name.substring(0, 2),
]);

/// Formats [d]'s date as ISO 'yyyy-MM-dd' (e.g. a Postgres `date`).
String formatIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Formats a DateTime as a German relative time string (e.g. "vor 5 Min.")
String formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  if (diff.inDays == 1) return 'vor 1 Tag';
  return 'vor ${diff.inDays} Tagen';
}

/// Formats a 7-day analysis date range string (e.g. "Analysiert: 6. Mär – 13. Mär 2026")
String formatAnalysisDateRange(DateTime createdAt) {
  final end = createdAt;
  final start = end.subtract(const Duration(days: 7));
  final df = DateFormat('d. MMM', 'de_DE');
  final yearFmt = DateFormat('yyyy');
  return 'Analysiert: ${df.format(start)} \u2013 ${df.format(end)} ${yearFmt.format(end)}';
}

/// Formats a DateTime as "DD.MM.YYYY HH:mm Uhr" (e.g., "13.03.2026 14:30 Uhr")
String formatDateTimeShort(DateTime dt) {
  return '${dt.day}.${dt.month}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')} Uhr';
}

/// Formats a DateTime as "d. MMMM yyyy" in German locale (e.g., "13. März 2026")
String formatDateLong(DateTime dt) {
  return DateFormat('d. MMMM yyyy', 'de_DE').format(dt);
}

/// Formats a DateTime as "HH:mm" (e.g., "14:30")
String formatTime(DateTime dt) {
  return DateFormat('HH:mm', 'de_DE').format(dt);
}

/// Formats a DateTime as "EEEE, dd.MM.yyyy HH:mm Uhr" in German locale
/// (e.g., "Freitag, 13.03.2026 14:30 Uhr")
String formatDateTimeFull(DateTime dt) {
  return '${DateFormat('EEEE, dd.MM.yyyy HH:mm', 'de_DE').format(dt)} Uhr';
}

/// Formats a DateTime as "EEEE dd.MM.yyyy" in German locale
/// (e.g., "Freitag 13.03.2026")
String formatDateWeekday(DateTime dt) {
  return DateFormat('EEEE dd.MM.yyyy', 'de_DE').format(dt);
}

/// Formats a DateTime as "EEEE, dd.MM" in German locale for compact
/// contexts like AppBar titles (e.g., "Montag, 15.04").
String formatDateWeekdayShort(DateTime dt) {
  return DateFormat('EEEE, dd.MM', 'de_DE').format(dt);
}

/// Formats a DateTime as "dd.MM.yyyy" (e.g., "13.03.2026")
String formatDateShort(DateTime dt) {
  return DateFormat('dd.MM.yyyy', 'de_DE').format(dt);
}

/// Returns true if [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The moment an entry for [initialDate] is logged at: [now] when null; on
/// today the current clock time (h:m of [now]); on any other day 12:00.
/// [now] defaults to [DateTime.now()]. Idempotent.
DateTime buildTrackedAt(DateTime? initialDate, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (initialDate == null) return current;
  final sameDay = isSameDay(initialDate, current);
  return DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
    sameDay ? current.hour : 12,
    sameDay ? current.minute : 0,
  );
}

/// The months' three-letter short forms, January first („Jan" … „Dez").
const List<String> kMonthShortNames = [
  'Jan',
  'Feb',
  'Mär',
  'Apr',
  'Mai',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Okt',
  'Nov',
  'Dez',
];

/// [day] as „Mi, 18. Nov".
String formatLogTargetDay(DateTime day) =>
    '${kWeekdayShortNames[day.weekday - 1]}, ${day.day}. '
    '${kMonthShortNames[day.month - 1]}';
