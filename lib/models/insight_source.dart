import 'gut_feeling_entry.dart';

/// A meal as the insights see it: when, and what was in it.
class InsightMeal {
  const InsightMeal({required this.trackedAt, required this.ingredients});

  final DateTime trackedAt;
  final List<String> ingredients;
}

/// Everything the insights are computed from, loaded once for the window.
class InsightSource {
  const InsightSource({
    required this.meals,
    required this.gutFeelings,
    required this.activityTimes,
  });

  /// Meals from 24 h before the window start on.
  final List<InsightMeal> meals;

  /// Gut-feeling entries in the window.
  final List<GutFeelingEntry> gutFeelings;

  /// `tracked_at` of every entry of all four tables inside the window, as
  /// local wall-clock times.
  final List<DateTime> activityTimes;
}
