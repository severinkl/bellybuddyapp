import '../../models/insights.dart';
import '../../models/progress.dart';
import '../../models/progress_rules.dart';
import '../../utils/date_format_utils.dart';
import '../insights/insight_copy.dart';

/// Every text of „Dein Verlauf" and its entries.
abstract final class ProgressCopy {
  static const title = 'Dein Verlauf';

  /// The „Ich" row's subtitle.
  static const meSubtitle = 'Wie es dir über die Wochen geht';

  /// The Muster page's link, under its footer.
  static const patternsLink =
      'Deinen Verlauf über ${ProgressRules.weeks} Wochen ansehen ›';

  static const header = 'Die letzten ${ProgressRules.weeks} Wochen';

  /// A count tile: „34 gute Tage", „1 guter Tag", „12 mittlere",
  /// „1 mittlerer", „6 schwere", „1 schwerer".
  static String classTotal(DayClass c, int n) =>
      c == DayClass.good ? _withNoun(c, n) : _adjective(c, n);

  /// „5 gute Tage", „1 mittlerer Tag".
  static String _withNoun(DayClass c, int n) =>
      '${_adjective(c, n)} ${n == 1 ? 'Tag' : 'Tage'}';

  /// „5 gute", „1 mittlerer".
  static String _adjective(DayClass c, int n) {
    final one = n == 1;
    final word = switch (c) {
      DayClass.good => one ? 'guter' : 'gute',
      DayClass.medium => one ? 'mittlerer' : 'mittlere',
      DayClass.hard => one ? 'schwerer' : 'schwere',
      DayClass.none => throw ArgumentError.value(c, 'c', 'not counted'),
    };
    return '$n $word';
  }

  /// The one comparison ever said, only when it holds
  /// ([Progress.moreGoodDaysLastWeek]).
  static const moreGoodDays =
      'Letzte Woche hattest du mehr gute Tage als die Woche davor.';

  static const currentStreak = 'Aktueller Streak';
  static const longestStreak = 'Längster Streak';
  static const longestSub = 'in den letzten ${ProgressRules.weeks} Wochen';

  /// A streak tile's number: „Startet mit deinem nächsten Eintrag" (0),
  /// „1 Tag", „5 Tage".
  static String streakDays(int n) => switch (n) {
    0 => 'Startet mit deinem nächsten Eintrag',
    1 => '1 Tag',
    _ => '$n Tage',
  };

  /// „Eingetragen an 61 von 84 Tagen".
  static String loggedTotal(int active, int elapsed) =>
      'Eingetragen an $active von $elapsed Tagen';

  /// A week row's label: „Diese Woche" for [today]'s week, else
  /// „17.–23. Nov", across months „27. Okt – 2. Nov".
  static String weekLabel(DateTime monday, DateTime today) {
    if (startOfDay(monday) == mondayOf(startOfDay(today))) {
      return 'Diese Woche';
    }
    final sunday = addDays(monday, 6);
    final end = '${sunday.day}. ${_month(sunday)}';
    return monday.month == sunday.month
        ? '${monday.day}.–$end'
        : '${monday.day}. ${_month(monday)} – $end';
  }

  static String _month(DateTime d) => kMonthShortNames[d.month - 1];

  /// A week's counts: „5 gute Tage, 1 schwerer", „1 guter Tag, 2 mittlere"
  /// (the first with the noun, zero classes left out, good to hard), or
  /// „Kein Bauchgefühl eingetragen".
  static String weekCounts(ProgressWeek w) {
    final parts = [
      for (final (c, n) in [
        (DayClass.good, w.good),
        (DayClass.medium, w.medium),
        (DayClass.hard, w.hard),
      ])
        if (n > 0) (c, n),
    ];
    if (parts.isEmpty) return 'Kein Bauchgefühl eingetragen';
    return [
      for (final (i, (c, n)) in parts.indexed)
        i == 0 ? _withNoun(c, n) : _adjective(c, n),
    ].join(', ');
  }

  /// After [weekCounts]: „ · an 6 von 7 Tagen eingetragen"; the current
  /// week on its first day „ · heute eingetragen" or „ · heute noch nichts
  /// eingetragen".
  static String weekLogged(ProgressWeek w) {
    if (w.elapsedDays == 1) {
      return w.activeDays > 0
          ? ' · heute eingetragen'
          : ' · heute noch nichts eingetragen';
    }
    return ' · an ${w.activeDays} von ${w.elapsedDays} Tagen eingetragen';
  }

  /// A day cell, to a screen reader: „18. Nov: gut", „18. Nov:
  /// eingetragen, ohne Bauchgefühl", „18. Nov: kein Eintrag".
  static String daySemantics(ProgressDay d) {
    final what = d.dayClass != DayClass.none
        ? InsightCopy.dayClassLabel(d.dayClass)
        : d.active
        ? 'eingetragen, $noGutFeelingLegend'
        : InsightCopy.dayClassLabel(DayClass.none);
    return '${d.day.day}. ${_month(d.day)}: $what';
  }

  /// The legend's label of an active day without a gut feeling.
  static const noGutFeelingLegend = 'ohne Bauchgefühl';

  static const emptyTitle = 'Dein Verlauf füllt sich bald';
  static const emptyBody =
      'Trag dein Bauchgefühl ein – dann siehst du hier Woche für Woche, wie '
      'es dir geht.';
  static const emptyAction = 'Bauchgefühl eintragen';

  static const loadError = 'Dein Verlauf konnte nicht geladen werden.';
  static const retry = 'Nochmal versuchen';
}
