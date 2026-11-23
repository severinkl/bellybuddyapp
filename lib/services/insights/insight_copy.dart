import '../../models/insight_progress.dart';
import '../../models/insights.dart';

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
          : 'Bauchgefühl-Einträge';
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

  /// „6 gute Tage in den letzten 30" (a shown column has at least
  /// [DayColumn.minDays] days, so always „Tage").
  static String goodDaysSub(DayColumn goodDays) =>
      '${goodDays.days} gute Tage in den letzten '
      '${InsightProgress.windowDays}';

  /// „A", „A und B", „A, B und C".
  static String _joined(List<String> items) => items.length < 2
      ? items.join()
      : '${items.sublist(0, items.length - 1).join(', ')} und ${items.last}';
}
