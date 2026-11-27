import '../../models/pattern_stats.dart';

/// German copy for „Genauer hingeschaut", the Muster page's 90-day
/// comparison (spec §4.5–4.7): every row with its counts, every level
/// relative, never a finding.
class StatsCopy {
  const StatsCopy._();

  static const title = 'Genauer hingeschaut';
  static const subtitle =
      'Letzte 90 Tage: wie oft ein schwerer Tag folgte – mit und ohne';

  static const groupsHeading = 'Nach FODMAP-Gruppen';
  static const looseHeading = 'Einzelne Zutaten';
  static const calmHeading = 'Bei dir unauffällig';

  static const nothingShown =
      'Über die längere Zeit fällt mir nichts Eindeutiges auf.';

  static const error = 'Der Vergleich ist gerade nicht verfügbar.';
  static const retry = 'Nochmal versuchen';

  static const limitsTitle = 'Was dieser Vergleich nicht kann';

  /// §4.5, in order: co-occurrence, time, amount, everything else, catalog.
  static const limits = [
    'Was oft zusammen auf dem Teller ist, fällt gemeinsam auf. Zwiebel und '
        'Knoblauch kann ich zum Beispiel schlecht auseinanderhalten, wenn du '
        'sie immer zusammen isst.',
    'Ich schaue auf die 24 Stunden vor deinem Bauchgefühl. Manches wirkt '
        'schneller oder langsamer.',
    'Ich weiß nicht, wie viel du gegessen hast – eine Prise ist für mich '
        'dasselbe wie ein Teller.',
    'Stress, Schlaf, Zyklus oder Medikamente sehe ich nicht. Die können '
        'genauso viel ausmachen.',
    'Die FODMAP-Gruppen kenne ich nur für Zutaten aus unserem Katalog.',
  ];

  /// The section's last line.
  static const closing = 'Ein Test sagt mehr als jeder Vergleich.';

  /// A shown row's badge; a calm item has none (its own heading says it).
  static String badge(StatLevel level) => switch (level) {
    StatLevel.strong => 'deutlich auffällig',
    StatLevel.noticed => 'auffällig',
    StatLevel.unsure => 'noch unsicher',
    StatLevel.calm => 'unauffällig',
  };

  /// „nach 7 von 10 Tagen mit Zwiebel ein schwerer Tag · ohne: 2 von 31".
  /// A shown item has E ≥ 4, so always „Tagen".
  static String rowLine(StatItem i) =>
      'nach ${i.exposedHard} von ${i.exposed} Tagen mit ${_dative(i)} ein '
      'schwerer Tag · ohne: ${i.unexposedHard} von ${i.unexposed}';

  /// „Reis · an 18 Tagen gegessen, nicht öfter schwere Tage" (calm needs
  /// E ≥ 8).
  static String calmLine(StatItem i) =>
      '${i.name} · an ${i.exposed} Tagen gegessen, nicht öfter schwere Tage';

  /// „Für diesen Vergleich brauche ich 14 Tage mit Bauchgefühl – bisher 9."
  static String notReady(int ratedDays) =>
      'Für diesen Vergleich brauche ich 14 Tage mit Bauchgefühl – bisher '
      '$ratedDays.';

  /// Group names after „mit": „Fruktane" is a plural („mit Fruktanen"); the
  /// other short labels (GOS, Laktose, Fruktose, Sorbit, Mannit) stay.
  static const _groupDative = {'fructans': 'Fruktanen'};

  static String _dative(StatItem i) => nameAfterMit(i.kind, i.key, i.name);

  /// [name] as it reads after „mit" (`group`/`ingredient` [kind], [key]).
  static String nameAfterMit(String kind, String key, String name) =>
      (kind == 'group' ? _groupDative[key] : null) ?? name;
}
