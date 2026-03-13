import 'package:intl/intl.dart';

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
