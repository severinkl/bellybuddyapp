import 'dart:math' as math;
import 'dart:ui';

import '../config/app_theme.dart';
import '../config/constants.dart';
import '../models/gut_feeling_entry.dart';

/// The four Bauchgefühl levels: sehr gut, gut, mittel, schlecht.
enum GutFeelingRatingLevel {
  spiGut('Sehr gut'),
  gut('Gut'),
  mittel('Mittel'),
  schlecht('Schlecht');

  final String label;

  const GutFeelingRatingLevel(this.label);
}

class GutFeelingRating {
  /// The entry's [gutFeelingScore] (1-5, higher = worse).
  final int score;
  final GutFeelingRatingLevel level;
  final Color color;

  const GutFeelingRating({
    required this.score,
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
    if (entry.stress != null && entry.stress! > 1)
      AppConstants.stimmungLabels[0],
    if (entry.happiness != null && entry.happiness! > 1)
      AppConstants.stimmungLabels[1],
    if (entry.energy != null && entry.energy! > 1)
      AppConstants.stimmungLabels[2],
    if (entry.focus != null && entry.focus! > 1) AppConstants.stimmungLabels[3],
    if (entry.bodyFeel != null && entry.bodyFeel! > 1)
      AppConstants.stimmungLabels[4],
  ];
  return active.isEmpty ? 'Alles gut' : active.join(', ');
}

/// The gut score of [entry]: its worst gut symptom (Blähbauch, Blähungen,
/// Krämpfe, Völlegefühl), 1 (none) to 5 (strong), higher = worse.
///
/// The one source for how an entry's Bauchgefühl is rated (diary, detail,
/// Buddy reaction, insights). The mood values (stress, happiness, energy,
/// focus, bodyFeel) never count.
int gutFeelingScore(GutFeelingEntry entry) => math.max(
  math.max(entry.bloating, entry.gas),
  math.max(entry.cramps, entry.fullness),
);

/// Maps a gut-feeling value (1-5 scale) to its rating level: a whole score
/// 1 → „Sehr gut", 2 → „Gut", 3 → „Mittel", 4-5 → „Schlecht";
/// a mean of scores falls between them at the half steps.
GutFeelingRatingLevel gutFeelingLevelFor(num value) {
  if (value <= 1.5) return GutFeelingRatingLevel.spiGut;
  if (value <= 2.5) return GutFeelingRatingLevel.gut;
  if (value <= 3.5) return GutFeelingRatingLevel.mittel;
  return GutFeelingRatingLevel.schlecht;
}

/// The overall gut-feeling rating of [entry], from its [gutFeelingScore].
GutFeelingRating calculateGutFeelingRating(GutFeelingEntry entry) {
  final score = gutFeelingScore(entry);
  return GutFeelingRating(
    score: score,
    level: gutFeelingLevelFor(score),
    color: getValueColor(score),
  );
}

/// What [score] (a [gutFeelingScore]) says, next to the rating level.
String gutFeelingScoreLabel(int score) =>
    score <= 1 ? 'Keine Beschwerden' : 'Stärkstes Symptom: $score von 5';
