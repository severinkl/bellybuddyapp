import 'package:flutter/foundation.dart' show listEquals, mapEquals;

import '../utils/json_values.dart';

/// The day-3 offer of a first tip.
enum TipOffer {
  /// Waiting for „Ja, gern" or „Nein, danke" (the weekly tips were off).
  offered,

  /// „Ja, gern": the first tip is the day-3 reward.
  accepted,

  /// „Nein, danke", or the sheet dismissed: a recipe instead.
  declined,

  /// The weekly tips were already on at day 3: no offer, a recipe instead.
  skipped,
}

/// The one-off first tip after „Ja, gern" on day 3.
enum FirstTipState { requested, done, failed }

/// A recipe the journey gave as a reward (days 1, 3 and 5), stored as it
/// was picked so it never changes.
class RecipePick {
  const RecipePick({
    required this.id,
    required this.title,
    this.matched = const [],
  });

  /// [json] when it has a string `id` and `title`; null on another shape.
  /// Non-string `matched` names are dropped.
  static RecipePick? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], title = json['title'];
    if (id is! String || title is! String) return null;
    return RecipePick(
      id: id,
      title: title,
      matched: List.unmodifiable(jsonStrings(json['matched'])),
    );
  }

  final String id, title;

  /// Day 5: the recipe's lines that match a calm-day ingredient, in recipe
  /// order, at most 3; empty when none did.
  final List<String> matched;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'matched': matched,
  };

  @override
  bool operator ==(Object other) =>
      other is RecipePick &&
      other.id == id &&
      other.title == title &&
      listEquals(other.matched, matched);

  @override
  int get hashCode => Object.hash(id, title, Object.hashAll(matched));

  @override
  String toString() => 'RecipePick($id, $title, matched: $matched)';
}

/// The rewards of the first 7 days for one user on one device: what was
/// earned, picked and answered. Never taken away: [earnedDay] never goes
/// down and a stored pick never changes (`advanceRewards`, `fillPicks`).
class JourneyRewards {
  const JourneyRewards({
    this.earnedDay = 0,
    this.patternsFreed = false,
    this.picks = const {},
    this.tipOffer,
    this.firstTip,
  });

  /// [json] when it is a map with an int `earned`; null otherwise. A pick
  /// of another shape is skipped, and an unknown answer reads null.
  static JourneyRewards? fromJson(Object? json) {
    if (json is! Map) return null;
    final earned = json['earned'];
    if (earned is! int) return null;
    return JourneyRewards(
      earnedDay: earned,
      patternsFreed: json['freed'] == true,
      picks: _picksFrom(json['picks']),
      tipOffer: TipOffer.values.asNameMap()[json['tipOffer']],
      firstTip: FirstTipState.values.asNameMap()[json['firstTip']],
    );
  }

  /// The latest day earned, 0–7: the active days, never lower.
  final int earnedDay;

  /// The first patterns were unlocked once (the day-7 reward).
  final bool patternsFreed;

  /// The recipe rewards, by day (1, 3, 5).
  final Map<int, RecipePick> picks;

  /// The day-3 offer; null while day 3 isn't decided.
  final TipOffer? tipOffer;

  /// The first tip after [TipOffer.accepted]; null before.
  final FirstTipState? firstTip;

  JourneyRewards copyWith({
    int? earnedDay,
    bool? patternsFreed,
    Map<int, RecipePick>? picks,
    TipOffer? tipOffer,
    FirstTipState? firstTip,
  }) => JourneyRewards(
    earnedDay: earnedDay ?? this.earnedDay,
    patternsFreed: patternsFreed ?? this.patternsFreed,
    picks: picks ?? this.picks,
    tipOffer: tipOffer ?? this.tipOffer,
    firstTip: firstTip ?? this.firstTip,
  );

  Map<String, Object?> toJson() => {
    'earned': earnedDay,
    'freed': patternsFreed,
    'picks': {
      for (final MapEntry(:key, :value) in picks.entries)
        '$key': value.toJson(),
    },
    'tipOffer': tipOffer?.name,
    'firstTip': firstTip?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is JourneyRewards &&
      other.earnedDay == earnedDay &&
      other.patternsFreed == patternsFreed &&
      mapEquals(other.picks, picks) &&
      other.tipOffer == tipOffer &&
      other.firstTip == firstTip;

  @override
  int get hashCode => Object.hash(
    earnedDay,
    patternsFreed,
    Object.hashAllUnordered(
      picks.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    tipOffer,
    firstTip,
  );

  @override
  String toString() =>
      'JourneyRewards(earnedDay: $earnedDay, patternsFreed: $patternsFreed, '
      'picks: $picks, tipOffer: ${tipOffer?.name}, '
      'firstTip: ${firstTip?.name})';
}

/// The picks stored in [json], by day; entries of another shape skipped.
Map<int, RecipePick> _picksFrom(Object? json) {
  final picks = <int, RecipePick>{};
  if (json is Map) {
    for (final MapEntry(:key, :value) in json.entries) {
      final day = key is String ? int.tryParse(key) : null;
      final pick = RecipePick.fromJson(value);
      if (day != null && pick != null) picks[day] = pick;
    }
  }
  return Map.unmodifiable(picks);
}
