import 'dart:ui';
import '../config/app_theme.dart';
import '../config/constants.dart';
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
  if (value <= 2) return AppTheme.gutFeelingGood;
  if (value <= 3) return AppTheme.gutFeelingNeutral;
  return AppTheme.gutFeelingBad;
}

/// Returns a comma-separated string of symptom/mood names where the value > 1.
/// Uses the same labels as the tracker sliders (rightLabel).
/// If everything is 1/5, returns 'Alles gut'.
String gutFeelingSubtitle(GutFeelingEntry entry) {
  final active = <String>[
    for (var i = 0; i < 4; i++)
      if ([entry.bloating, entry.gas, entry.cramps, entry.fullness][i] > 1)
        AppConstants.gutFeelingSymptoms[i],
    if (entry.stress != null && entry.stress! > 1) AppConstants.stimmungLabels[0],
    if (entry.happiness != null && entry.happiness! > 1) AppConstants.stimmungLabels[1],
    if (entry.energy != null && entry.energy! > 1) AppConstants.stimmungLabels[2],
    if (entry.focus != null && entry.focus! > 1) AppConstants.stimmungLabels[3],
    if (entry.bodyFeel != null && entry.bodyFeel! > 1) AppConstants.stimmungLabels[4],
  ];
  return active.isEmpty ? 'Alles gut' : active.join(', ');
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
