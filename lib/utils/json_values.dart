/// The strings of a JSON list, other entries skipped; none when [value]
/// isn't a list.
Iterable<String> jsonStrings(Object? value) =>
    value is List ? value.whereType<String>() : const [];

/// [value] trimmed when it is a string with more than blanks; null
/// otherwise.
String? trimmedOrNull(Object? value) {
  final trimmed = value is String ? value.trim() : null;
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
