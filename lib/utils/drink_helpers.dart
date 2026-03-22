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

  /// Multi-word search with prefix-weighted ranking.
  /// Returns at most 8 results.
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
    return filtered.take(8).toList();
  }

  /// Parses a custom amount string into a positive int, or null.
  static int? parseAmount(String value) {
    final parsed = int.tryParse(value);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Formats milliliters as a human-readable string.
  /// >= 1000 ml → liters (e.g. "1.5 L"), otherwise "250 ml".
  static String formatAmount(int ml) {
    if (ml >= 1000) {
      final liters = (ml / 1000).toStringAsFixed(1);
      return '${liters.replaceAll('.0', '')} L';
    }
    return '$ml ml';
  }
}
