import '../../models/insight_progress.dart';
import '../../models/insights.dart';
import '../../utils/date_format_utils.dart';

/// German copy for Home's insight card and the Muster page: observations
/// from the user's own entries, with their counts, never a finding.
class InsightCopy {
  const InsightCopy._();

  /// Card header while locked, and when nothing stands out yet.
  static const learningTitle = 'Was ich über deinen Bauch lerne';

  /// Card header of a [NoticedPick]; also the page's section.
  static const noticedTitle = 'Fällt mir auf';

  /// Card header of a [GoodDaysPick].
  static const goodDaysTitle = 'Deine guten Tage';

  /// The card's trailing link to the Muster page.
  static const patternsLink = 'Muster ›';

  /// What the card says it does, to a screen reader.
  static const openPatterns = 'Muster ansehen';

  static const nothingYet =
      'Noch fällt mir nichts Eindeutiges auf – trag weiter ein, dann sehe ich '
      'mehr.';

  /// Next to every observation: it is not a medical finding.
  static const noFinding = 'kein Befund';

  /// The progress bars' labels (card and page, while locked).
  static const activeDaysLabel = 'Tage mit Einträgen';
  static const gutFeelingEntriesLabel = 'Bauchgefühl-Einträge';

  static const _soon = 'dann zeig ich dir erste Muster.';

  /// The Buddy's line while locked: what is still missing, days first.
  static String lockedLine(InsightProgress p) {
    if (p.daysLeft > 0) {
      final days = p.daysLeft == 1 ? 'Tag' : 'Tage';
      return 'Noch ${p.daysLeft} $days, $_soon';
    }
    if (p.gutFeelingsLeft > 0) {
      final entries = p.gutFeelingsLeft == 1
          ? 'Bauchgefühl-Eintrag'
          : gutFeelingEntriesLabel;
      return 'Noch ${p.gutFeelingsLeft} $entries, $_soon';
    }
    // Unlocked progress shows the insights instead of this line.
    return 'Genug Einträge! Deine ersten Muster kommen bald.';
  }

  /// „Zwiebel war an 4 von 5 schweren Tagen dabei." (a noticed item has at
  /// least [Noticed.minHardDays] hard days, so always „Tagen").
  static String noticedHeadline(Noticed n) =>
      '${n.name} war ${_onHardDays(n)} dabei.';

  /// „an guten Tagen: 1 von 6", or „an guten Tagen: noch keine" without
  /// good days in the window.
  static String noticedGood(Noticed n) => n.goodDays == 0
      ? 'an guten Tagen: noch keine'
      : 'an guten Tagen: ${n.good} von ${n.goodDays}';

  /// The page's row: „Zwiebel · an 4 von 5 schweren Tagen dabei · an guten
  /// Tagen: 1 von 6".
  static String noticedRow(Noticed n) =>
      '${n.name} · ${_onHardDays(n)} dabei · ${noticedGood(n)}';

  static String _onHardDays(Noticed n) =>
      'an ${n.hard} von ${n.hardDays} schweren Tagen';

  /// „An guten Tagen gab's oft Haferflocken, Reis und Karotte."
  static String goodDaysLine(DayColumn goodDays) {
    final names = [for (final item in goodDays.often) item.name];
    return "An guten Tagen gab's oft ${_joined(names)}.";
  }

  /// „6 gute Tage in den letzten 30".
  static String goodDaysSub(DayColumn goodDays) =>
      '${columnTitle(goodDays, hard: false)} in den letzten '
      '${InsightProgress.windowDays}';

  // The Muster page, once unlocked.

  /// The calendar's header: „Letzte 30 Tage · 21 Tage mit Bauchgefühl".
  static String calendarHeader(int gutFeelingDays) {
    final days = gutFeelingDays == 1 ? 'Tag' : 'Tage';
    return 'Letzte ${InsightProgress.windowDays} Tage · $gutFeelingDays '
        '$days mit Bauchgefühl';
  }

  /// A day's class in the calendar and its legend: „gut", „mittel",
  /// „schwer", „kein Eintrag".
  static String dayClassLabel(DayClass c) => switch (c) {
    DayClass.good => 'gut',
    DayClass.medium => 'mittel',
    DayClass.hard => 'schwer',
    DayClass.none => 'kein Eintrag',
  };

  /// A calendar day, to a screen reader: „18. Nov: schwer".
  static String daySemantics(InsightDay d) =>
      '${d.day.day}. ${kMonthShortNames[d.day.month - 1]}: '
      '${dayClassLabel(d.dayClass)}';

  /// The section of both columns.
  static const columnsTitle = 'Deine guten und schweren Tage';

  /// A column's title: „6 gute Tage", „1 guter Tag", „5 schwere Tage",
  /// „1 schwerer Tag".
  static String columnTitle(DayColumn c, {required bool hard}) {
    final one = c.days == 1;
    final adjective = hard
        ? (one ? 'schwerer' : 'schwere')
        : (one ? 'guter' : 'gute');
    return '${c.days} $adjective ${one ? 'Tag' : 'Tage'}';
  }

  /// Above a shown column's items.
  static const oftenLabel = 'oft dabei:';

  /// A column item: „Reis · an 3 von 4 guten Tagen" (an item is there on
  /// at least 2 days, so always „Tagen").
  static String oftenRow(IngredientCount i, {required bool hard}) =>
      '${i.name} · an ${i.count} von ${i.of} '
      '${hard ? 'schweren' : 'guten'} Tagen';

  /// A shown column without items.
  static const nothingOften = 'Noch nichts, das oft dabei war.';

  /// A column below [DayColumn.minDays] days.
  static String tooFewDays({required bool hard}) =>
      'Noch zu wenige ${hard ? 'schwere' : 'gute'} Tage';

  /// The badge of a „Fällt mir auf" item seen on only 2 hard days.
  static const uncertain = 'noch unsicher';

  /// The Muster page's footer, locked or not.
  static const footer =
      'ⓘ Beobachtung aus deinen Einträgen, kein medizinischer Befund.';

  /// Below the [footer], once unlocked: what the classes mean.
  static const dayDefinitions =
      'Schwerer Tag = Bauchgefühl „Schlecht"; guter Tag = „Gut" oder '
      '„Sehr gut".';

  /// „A", „A und B", „A, B und C".
  static String _joined(List<String> items) => items.length < 2
      ? items.join()
      : '${items.sublist(0, items.length - 1).join(', ')} und ${items.last}';
}
