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

/// The one of [values] whose [wire] value is [raw]; null for one this
/// build does not know.
T? lookupWire<T>(Iterable<T> values, String Function(T) wire, Object? raw) {
  for (final v in values) {
    if (wire(v) == raw) return v;
  }
  return null;
}

/// [lookupWire], throwing a [FormatException] („unknown [what]: …") for a
/// value this build does not know.
T requireWire<T>(
  Iterable<T> values,
  String Function(T) wire,
  Object? raw,
  String what,
) =>
    lookupWire(values, wire, raw) ??
    (throw FormatException('unknown $what: $raw'));
