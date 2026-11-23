import 'insight_progress.dart';

/// How a day went, from the mean of its gut-feeling entries' scores (each
/// the entry's worst gut symptom, `gutFeelingScore`) and the levels of
/// `gutFeelingLevelFor` (higher = worse).
enum DayClass {
  /// „Sehr gut" or „Gut": a mean of at most 2.5.
  good,

  /// „Durchschnittlich": above 2.5, at most 3.5.
  medium,

  /// „Schlecht": above 3.5.
  hard,

  /// No gut-feeling entry that day („kein Eintrag").
  none,
}

/// One day of the insights calendar.
class InsightDay {
  const InsightDay({required this.day, required this.dayClass});

  /// The local day, at midnight.
  final DateTime day;

  final DayClass dayClass;

  @override
  bool operator ==(Object other) =>
      other is InsightDay && other.day == day && other.dayClass == dayClass;

  @override
  int get hashCode => Object.hash(day, dayClass);

  @override
  String toString() => 'InsightDay($day, ${dayClass.name})';
}

/// An ingredient that was there before [count] of the [of] days of a
/// column: „Reis · an 3 von 4 guten Tagen".
class IngredientCount {
  const IngredientCount(this.name, this.count, {required this.of});

  /// The trimmed spelling from the most recent meal that lists it.
  final String name;

  /// Days of the column it was there on (in the 24 h before the day's
  /// first entry of the column's class).
  final int count;

  /// All days of the column ([DayColumn.days]).
  final int of;

  @override
  bool operator ==(Object other) =>
      other is IngredientCount &&
      other.name == name &&
      other.count == count &&
      other.of == of;

  @override
  int get hashCode => Object.hash(name, count, of);

  @override
  String toString() => 'IngredientCount($name, $count of $of)';
}

/// The good or the hard days of the window („Deine guten Tage" /
/// „Deine schweren Tage") and what was often there before them.
class DayColumn {
  const DayColumn({required this.days, this.often = const []});

  /// A column needs this many days of its class to be [shown].
  static const minDays = 3;

  /// Days of the column's class in the window.
  final int days;

  /// Whether there are enough [days] to show the column. Otherwise the
  /// page says „Noch zu wenige gute/schwere Tage".
  bool get shown => days >= minDays;

  /// „oft dabei": ingredients there on at least 2 of the [days] and on at
  /// least half of them. Most frequent first, then by name; at most 5.
  /// Empty while the column is not [shown].
  final List<IngredientCount> often;

  @override
  bool operator ==(Object other) =>
      other is DayColumn &&
      other.days == days &&
      _listEquals(other.often, often);

  @override
  int get hashCode => Object.hash(days, Object.hashAll(often));

  @override
  String toString() => 'DayColumn(days: $days, often: $often)';
}

/// An ingredient that was there before hard days clearly more often than
/// before good days („Fällt mir auf"): „Zwiebel · an 4 von 5 schweren Tagen
/// dabei · an guten Tagen: 1 von 6".
class Noticed {
  const Noticed({
    required this.name,
    required this.hard,
    required this.hardDays,
    required this.good,
    required this.goodDays,
    this.uncertain = false,
  });

  /// „Fällt mir auf" appears only with at least this many hard days in the
  /// window.
  static const minHardDays = 3;

  /// The trimmed spelling from the most recent meal that lists it.
  final String name;

  /// Hard days it was there on.
  final int hard;

  /// All hard days in the window.
  final int hardDays;

  /// Good days it was there on.
  final int good;

  /// All good days in the window; 0 reads „an guten Tagen: noch keine".
  final int goodDays;

  /// There on only 2 hard days so far: marked „noch unsicher".
  final bool uncertain;

  @override
  bool operator ==(Object other) =>
      other is Noticed &&
      other.name == name &&
      other.hard == hard &&
      other.hardDays == hardDays &&
      other.good == good &&
      other.goodDays == goodDays &&
      other.uncertain == uncertain;

  @override
  int get hashCode =>
      Object.hash(name, hard, hardDays, good, goodDays, uncertain);

  @override
  String toString() =>
      'Noticed($name: hard $hard of $hardDays, good $good of $goodDays'
      '${uncertain ? ', uncertain' : ''})';
}

/// What Home's insight card shows once the insights are unlocked.
sealed class InsightPick {
  const InsightPick();
}

/// The top „Fällt mir auf" item (never an uncertain one).
final class NoticedPick extends InsightPick {
  const NoticedPick(this.noticed);

  final Noticed noticed;

  @override
  bool operator ==(Object other) =>
      other is NoticedPick && other.noticed == noticed;

  @override
  int get hashCode => noticed.hashCode;

  @override
  String toString() => 'NoticedPick($noticed)';
}

/// Nothing stands out, but the good days have ingredients „oft dabei":
/// „An guten Tagen gab's oft Haferflocken, Reis und Karotte".
final class GoodDaysPick extends InsightPick {
  const GoodDaysPick(this.goodDays);

  /// The shown good-days column, with at least one item.
  final DayColumn goodDays;

  @override
  bool operator ==(Object other) =>
      other is GoodDaysPick && other.goodDays == goodDays;

  @override
  int get hashCode => goodDays.hashCode;

  @override
  String toString() => 'GoodDaysPick($goodDays)';
}

/// Nothing to tell yet: „Noch fällt mir nichts Eindeutiges auf".
final class NothingYetPick extends InsightPick {
  const NothingYetPick();

  @override
  bool operator ==(Object other) => other is NothingYetPick;

  @override
  int get hashCode => (NothingYetPick).hashCode;

  @override
  String toString() => 'NothingYetPick()';
}

/// What the last 30 local days of entries show (`computeInsights`):
/// observations from the user's own entries, never a finding. Everything
/// except [progress] is meant for display only once [unlocked].
class Insights {
  const Insights({
    required this.progress,
    required this.calendar,
    required this.goodDays,
    required this.hardDays,
    required this.noticed,
    required this.pick,
  });

  /// Toward the first patterns: active days and gut-feeling entries.
  final InsightProgress progress;

  bool get unlocked => progress.unlocked;

  /// Every day of the window, oldest first; the last one is today.
  final List<InsightDay> calendar;

  /// Days in the window with at least one gut-feeling entry.
  int get gutFeelingDays =>
      calendar.where((d) => d.dayClass != DayClass.none).length;

  final DayColumn goodDays;

  final DayColumn hardDays;

  /// „Fällt mir auf": the shown items (at most 5), then the „noch unsicher"
  /// ones (at most 3). Empty below [Noticed.minHardDays] hard days.
  final List<Noticed> noticed;

  /// What Home's card shows once [unlocked].
  final InsightPick pick;

  @override
  bool operator ==(Object other) =>
      other is Insights &&
      other.progress == progress &&
      _listEquals(other.calendar, calendar) &&
      other.goodDays == goodDays &&
      other.hardDays == hardDays &&
      _listEquals(other.noticed, noticed) &&
      other.pick == pick;

  @override
  int get hashCode => Object.hash(
    progress,
    Object.hashAll(calendar),
    goodDays,
    hardDays,
    Object.hashAll(noticed),
    pick,
  );

  @override
  String toString() =>
      'Insights($progress, goodDays: $goodDays, hardDays: $hardDays, '
      'noticed: $noticed, pick: $pick)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
