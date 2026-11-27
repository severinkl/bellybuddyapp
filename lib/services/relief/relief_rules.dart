import 'dart:convert';

import '../../models/gut_feeling_entry.dart';
import 'relief_content.dart';

/// How an exercise felt; stored as `yes` | `little` | `no`.
enum ReliefAnswer { yes, little, no }

/// [all] with the exercises answered `yes` first, `no` last and the rest
/// (`little`, unanswered) between them; each group keeps content order.
List<ReliefExercise> orderedExercises(
  List<ReliefExercise> all,
  Map<String, ReliefAnswer> answers,
) {
  int rank(ReliefExercise e) => switch (answers[e.id]) {
    ReliefAnswer.yes => 0,
    ReliefAnswer.no => 2,
    _ => 1,
  };
  return [
    for (final r in [0, 1, 2]) ...all.where((e) => rank(e) == r),
  ];
}

/// The answers stored as JSON, or null when [json] is corrupt (not JSON, or
/// not a map); null input is simply empty. Ids not in [knownIds] and unknown
/// answers are dropped.
Map<String, ReliefAnswer>? tryParseReliefAnswers(
  String? json, {
  required Set<String> knownIds,
}) {
  if (json == null) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return null;
    final result = <String, ReliefAnswer>{};
    for (final entry in decoded.entries) {
      final id = entry.key;
      final answer = ReliefAnswer.values
          .where((a) => a.name == entry.value)
          .firstOrNull;
      if (id is String && answer != null && knownIds.contains(id)) {
        result[id] = answer;
      }
    }
    return result;
  } on FormatException {
    return null;
  }
}

/// Whether [entry] (a symptom of 4+ logged within the last 2 hours) offers
/// the exercises. Wall clock on both sides: no time zone conversion.
bool offersRelief(GutFeelingEntry entry, {required DateTime now}) {
  final strong = [
    entry.bloating,
    entry.gas,
    entry.cramps,
    entry.fullness,
  ].any((v) => v >= 4);
  return strong &&
      !entry.trackedAt.isBefore(now.subtract(const Duration(hours: 2))) &&
      !entry.trackedAt.isAfter(now.add(const Duration(minutes: 5)));
}
