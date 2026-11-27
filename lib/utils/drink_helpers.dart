import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../config/constants.dart';
import '../models/drink.dart';
import '../models/drink_icon.dart';
import 'date_format_utils.dart';

export '../models/drink_icon.dart';

enum DrinkVessel {
  glass('Glas', 250),
  can('Dose', 330),
  bottle('Flasche', 500),
  large('Große', 1000);

  const DrinkVessel(this.label, this.ml);
  final String label;
  final int ml;
}

/// Shares (0-1) of one glass that are drunk and still pending.
typedef GlassFill = ({double drunk, double pending});

typedef LastDrink = ({Drink drink, int amountMl});

const _canKeywords = [
  'cola',
  'energy',
  'red bull',
  'bier',
  'radler',
  'spezi',
  'tonic',
  'ginger ale',
  'fanta',
  'sprite',
  'mezzo',
];
const _bottleKeywords = [
  'saft',
  'schorle',
  'limo',
  'nektar',
  'smoothie',
  'eistee',
  'kombucha',
  'sirup',
];
const _cupKeywords = [
  'kaffee',
  'espresso',
  'cappuccino',
  'latte',
  'macchiato',
  'americano',
  'cortado',
  'flat white',
  'mokka',
];
const _hotCupKeywords = ['tee', 'chai', 'mate', 'rooibos', 'kakao', 'brühe'];
const _cartonKeywords = [
  'milch',
  'drink',
  'kefir',
  'ayran',
  'lassi',
  'buttermilch',
];

abstract final class DrinkHelpers {
  /// Builds a "quick drinks" list: Wasser first, then recent drinks,
  /// falling back to first 11 drinks if no recent history.
  static List<Drink> buildQuickDrinks(
    List<Drink> allDrinks,
    List<String> recentIds,
  ) {
    final quick = <Drink>[];
    final wasserDrink = allDrinks.where(_isWasser).firstOrNull;
    if (wasserDrink != null) quick.add(wasserDrink);
    for (final id in recentIds) {
      if (id == wasserDrink?.id) continue;
      final drink = allDrinks.where((d) => d.id == id).firstOrNull;
      if (drink != null) quick.add(drink);
    }
    final seen = {for (final d in quick) d.id};
    for (final starter in AppConstants.starterDrinkNames) {
      if (quick.length >= AppConstants.drinkTileCount) break;
      final lower = starter.toLowerCase();
      final drink = allDrinks
          .where((d) => d.name.toLowerCase() == lower)
          .firstOrNull;
      if (drink != null && seen.add(drink.id)) quick.add(drink);
    }
    if (quick.isEmpty) {
      return allDrinks.take(AppConstants.drinkFallbackCount).toList();
    }
    return quick;
  }

  /// The icon of a drink: its category's, else by its name.
  static DrinkIcon iconFor(Drink drink) =>
      drink.categoryIcon ?? iconForName(drink.name);

  /// The icon for a drink name: the first keyword group (can, bottle, cup,
  /// hot cup, carton) with a keyword in the lower-cased name, else glass.
  static DrinkIcon iconForName(String name) {
    final n = name.toLowerCase();
    bool has(List<String> keywords) => keywords.any(n.contains);
    if (has(_canKeywords)) return DrinkIcon.can;
    if (has(_bottleKeywords)) return DrinkIcon.bottle;
    if (has(_cupKeywords)) return DrinkIcon.cup;
    if (has(_hotCupKeywords)) return DrinkIcon.hotCup;
    if (has(_cartonKeywords)) return DrinkIcon.carton;
    return DrinkIcon.glass;
  }

  /// The glasses of the today card: drunk and pending share of each
  /// [AppConstants.drinkGlassMl] glass, at least one, at most
  /// [AppConstants.glassMeterMaxGlasses].
  static List<GlassFill> glassFills(int drunkMl, int pendingMl) {
    const glass = AppConstants.drinkGlassMl;
    final total = drunkMl + pendingMl;
    final count = math.min(
      AppConstants.glassMeterMaxGlasses,
      math.max(1, (total / glass).ceil()),
    );
    return [
      for (var i = 0; i < count; i++)
        () {
          final drunk = (drunkMl - glass * i).clamp(0, glass) / glass;
          final upTo = (total - glass * i).clamp(0, glass) / glass;
          return (drunk: drunk, pending: upTo - drunk);
        }(),
    ];
  }

  /// Spoken description of [glassFills].
  static String glassesLabel(int drunkMl, int pendingMl) {
    const glass = AppConstants.drinkGlassMl;
    final full = drunkMl ~/ glass;
    final rest = drunkMl % glass;
    final String drunk;
    if (drunkMl == 0) {
      drunk = 'Nichts eingetragen';
    } else if (full == 0) {
      drunk = '$rest ml getrunken';
    } else {
      final glasses = full == 1
          ? '1 Glas zu $glass ml'
          : '$full Gläser zu je $glass ml';
      drunk = rest == 0
          ? '$glasses getrunken'
          : '$glasses und $rest ml getrunken';
    }
    return pendingMl > 0
        ? '$drunk, dazu kommen ${formatAmount(pendingMl)}'
        : drunk;
  }

  static bool _isWasser(Drink d) => d.name.toLowerCase() == 'wasser';

  /// The drink tiles: Wasser first, the rest in order without duplicates,
  /// at most [count]; a [selected] drink not among them replaces the last.
  static List<Drink> tileDrinks(
    List<Drink> quick,
    Drink? selected, {
    int count = AppConstants.drinkTileCount,
  }) {
    final seen = <String>{};
    final tiles = [
      for (final d in [?quick.where(_isWasser).firstOrNull, ...quick])
        if (seen.add(d.id)) d,
    ].take(count).toList();
    if (selected != null && !tiles.any((d) => d.id == selected.id)) {
      if (tiles.isNotEmpty && tiles.length >= count) tiles.removeLast();
      tiles.add(selected);
    }
    return tiles;
  }

  /// The label of the save button.
  static String saveLabel(Drink drink, int? amountMl) => amountMl == null
      ? '${drink.name} eintragen'
      : '${formatAmount(amountMl)} ${drink.name} eintragen';

  /// „Heute, 14:30" / „Gestern, 14:30" / „19. Nov., 09:05".
  static String timeLabel(DateTime at, DateTime now) {
    final label = formatRecentDayTime(at, now);
    return label[0].toUpperCase() + label.substring(1);
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
    // The name, else the first synonym that holds every word, is what
    // matched and what the ranking looks at.
    String? matched(Drink d) {
      for (final text in [d.name, ...d.synonyms]) {
        final lower = text.toLowerCase();
        if (words.every(lower.contains)) return lower;
      }
      return null;
    }

    final hits = <(Drink, String)>[
      for (final d in allDrinks)
        if (matched(d) case final m?) (d, m),
    ];
    final firstWord = words.first;
    hits.sort((a, b) {
      final aStarts = a.$2.startsWith(firstWord);
      final bStarts = b.$2.startsWith(firstWord);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      final aWordStarts = a.$2.split(' ').any((w) => w.startsWith(firstWord));
      final bWordStarts = b.$2.split(' ').any((w) => w.startsWith(firstWord));
      if (aWordStarts && !bWordStarts) return -1;
      if (!aWordStarts && bWordStarts) return 1;

      return a.$1.name.compareTo(b.$1.name);
    });
    final filtered = [for (final h in hits) h.$1];
    return filtered.take(searchResultLimit).toList();
  }

  /// The largest amount one drink entry may have, in ml.
  static const maxAmountMl = 3000;

  /// Parses a custom amount string into an amount of 1 to [maxAmountMl]
  /// ml, or null.
  static int? parseAmount(String value) {
    final parsed = int.tryParse(value);
    return (parsed != null && isValidAmount(parsed)) ? parsed : null;
  }

  /// Whether [ml] is an amount one drink entry may have: 1 to [maxAmountMl].
  static bool isValidAmount(int ml) => ml > 0 && ml <= maxAmountMl;

  /// The hint for a typed amount that [parseAmount] refuses; null for an
  /// empty field or a valid amount.
  static String? amountError(String value) {
    if (value.trim().isEmpty || parseAmount(value.trim()) != null) return null;
    return 'Bitte gib 1 bis $maxAmountMl ml ein.';
  }

  static final _liters = NumberFormat('0.#', 'de');

  /// Formats milliliters as a human-readable string.
  /// >= 1000 ml → liters with a German decimal comma (e.g. "1,5 l"),
  /// otherwise "250 ml".
  static String formatAmount(int ml) {
    if (ml >= 1000) return '${_liters.format(ml / 1000)} l';
    return '$ml ml';
  }
}
