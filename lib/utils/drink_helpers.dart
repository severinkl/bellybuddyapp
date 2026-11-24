import 'package:intl/intl.dart';

import '../models/drink.dart';

abstract final class DrinkHelpers {
  /// Builds a "quick drinks" list: Wasser first, then recent drinks,
  /// falling back to first 11 drinks if no recent history.
  static List<Drink> buildQuickDrinks(
    List<Drink> allDrinks,
    List<String> recentIds,
  ) {
    final quick = <Drink>[];
    final wasserDrink = allDrinks
        .where((d) => d.name.toLowerCase() == 'wasser')
        .firstOrNull;
    if (wasserDrink != null) quick.add(wasserDrink);
    for (final id in recentIds) {
      if (id == wasserDrink?.id) continue;
      final drink = allDrinks.where((d) => d.id == id).firstOrNull;
      if (drink != null) quick.add(drink);
    }
    if (quick.isEmpty) return allDrinks.take(11).toList();
    return quick;
  }

  /// Maximum number of suggestions returned by [search].
  static const searchResultLimit = 30;

  /// Multi-word search with prefix-weighted ranking.
  /// Returns at most [searchResultLimit] results.
  static List<Drink> search(String query, List<Drink> allDrinks) {
    if (query.trim().isEmpty) return [];
    final words = query
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final filtered =
        allDrinks.where((d) {
          final name = d.name.toLowerCase();
          return words.every((w) => name.contains(w));
        }).toList()..sort((a, b) {
          final firstWord = words.first;
          final aName = a.name.toLowerCase();
          final bName = b.name.toLowerCase();

          final aStarts = aName.startsWith(firstWord);
          final bStarts = bName.startsWith(firstWord);
          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;

          final aWordStarts = aName
              .split(' ')
              .any((w) => w.startsWith(firstWord));
          final bWordStarts = bName
              .split(' ')
              .any((w) => w.startsWith(firstWord));
          if (aWordStarts && !bWordStarts) return -1;
          if (!aWordStarts && bWordStarts) return 1;

          return a.name.compareTo(b.name);
        });
    return filtered.take(searchResultLimit).toList();
  }

  /// The largest amount one drink entry may have, in ml.
  static const maxAmountMl = 3000;

  /// Parses a custom amount string into an amount of 1 to [maxAmountMl]
  /// ml, or null.
  static int? parseAmount(String value) {
    final parsed = int.tryParse(value);
    return (parsed != null && parsed > 0 && parsed <= maxAmountMl)
        ? parsed
        : null;
  }

  /// The hint for a typed amount that [parseAmount] refuses; null for an
  /// empty field or a valid amount.
  static String? amountError(String value) {
    if (value.trim().isEmpty || parseAmount(value.trim()) != null) return null;
    return 'Bitte gib 1 bis $maxAmountMl ml ein.';
  }

  static final _liters = NumberFormat('0.#', 'de');

  /// Formats milliliters as a human-readable string.
  /// >= 1000 ml → liters with a German decimal comma (e.g. "1,5 L"),
  /// otherwise "250 ml".
  static String formatAmount(int ml) {
    if (ml >= 1000) return '${_liters.format(ml / 1000)} L';
    return '$ml ml';
  }
}
