/// [items] without blank or repeated names (by [nameOf], trimmed, case
/// ignored), the first of each kept, in order. A kept item brings whatever
/// else it carries, so e.g. its amount stays aligned with its name.
List<T> distinctByName<T>(Iterable<T> items, String Function(T item) nameOf) {
  final seen = <String>{};
  return [
    for (final item in items)
      if (nameOf(item).trim().toLowerCase() case final key
          when key.isNotEmpty && seen.add(key))
        item,
  ];
}
