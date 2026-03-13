import 'dart:ui';
import '../models/gut_feeling_entry.dart';

enum GutFeelingRatingLevel {
  spiGut('Sehr gut'),
  gut('Gut'),
  durchschnittlich('Durchschnittlich'),
  schlecht('Schlecht');

  final String label;
  const GutFeelingRatingLevel(this.label);
}

class GutFeelingRating {
  final double avg;
  final GutFeelingRatingLevel level;
  final Color color;

  const GutFeelingRating({
    required this.avg,
    required this.level,
    required this.color,
  });
}

/// Returns the color for a single gut-feeling value (1-5 scale).
Color getValueColor(int value) {
  if (value <= 2) return const Color(0xFF40BF40); // hsl(120, 60%, 50%)
  if (value <= 3) return const Color(0xFFE6B800); // hsl(45, 80%, 50%)
  return const Color(0xFFD93636); // hsl(0, 70%, 50%)
}

/// Calculates the overall gut-feeling rating from an entry.
/// Averages all present values (bloating, gas, cramps, fullness +
/// optional mood values). Lower is better (1 = best, 5 = worst).
GutFeelingRating calculateGutFeelingRating(GutFeelingEntry entry) {
  final values = <int>[
    entry.bloating,
    entry.gas,
    entry.cramps,
    entry.fullness,
  ];

  if (entry.happiness != null) values.add(entry.happiness!);
  if (entry.energy != null) values.add(entry.energy!);
  if (entry.focus != null) values.add(entry.focus!);
  if (entry.bodyFeel != null) values.add(entry.bodyFeel!);
  if (entry.stress != null) values.add(entry.stress!);

  final avg = values.reduce((a, b) => a + b) / values.length;

  final GutFeelingRatingLevel level;
  if (avg <= 1.5) {
    level = GutFeelingRatingLevel.spiGut;
  } else if (avg <= 2.5) {
    level = GutFeelingRatingLevel.gut;
  } else if (avg <= 3.5) {
    level = GutFeelingRatingLevel.durchschnittlich;
  } else {
    level = GutFeelingRatingLevel.schlecht;
  }

  return GutFeelingRating(
    avg: avg,
    level: level,
    color: getValueColor(avg.round()),
  );
}
