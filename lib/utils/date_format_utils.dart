import 'package:intl/intl.dart';

/// Returns the start of the given day (midnight).
DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns the start of the next day (exclusive end bound for date queries).
DateTime endOfDay(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day).add(const Duration(days: 1));

/// Returns the ISO-8601 string for 7 days before [now] (defaults to now).
DateTime last7Days([DateTime? now]) =>
    (now ?? DateTime.now()).subtract(const Duration(days: 7));

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

/// Formats a DateTime as "dd.MM.yyyy" (e.g., "13.03.2026")
String formatDateShort(DateTime dt) {
  return DateFormat('dd.MM.yyyy', 'de_DE').format(dt);
}

/// Returns true if [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
