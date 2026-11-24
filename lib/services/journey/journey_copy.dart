import '../../utils/german_list.dart';

/// German copy for the rewards of the first 7 days: what the Buddy gives,
/// never a health claim. A matched ingredient is an observation from the
/// user's own entries, never a promise that it helps.
abstract final class JourneyCopy {
  // The titles, in the reward line and in „Deine Belohnungen".

  static const day1 = 'Dein erstes Rezept';
  static const day2 = 'Ein Wissen-Häppchen';

  /// Day 3 after „Ja, gern", and before the answer while the weekly tips
  /// are off.
  static const day3Tip = 'Dein erster Tipp';

  /// Day 3 after „Nein, danke", or with the weekly tips already on.
  static const day3Recipe = 'Ein Rezept für dich';

  static const day4 = 'Ein Spruch von mir';

  /// Day 5 with a recipe matching calm-day ingredients …
  static const day5 = 'Ein Rezept mit deinen Zutaten';

  /// … and without one, so the copy never claims a match.
  static const day5Generic = 'Noch ein Rezept für dich';

  static const day6 = 'Eine Vorschau auf deine Muster';
  static const day7 = 'Deine ersten Muster';

  /// The reward line once today's dot is filled …
  static String today(String title) => 'Heute: $title';

  /// … before today's first entry …
  static String waiting(String title) => 'Heute wartet: $title';

  /// … and for day 7 while it needs more than today's entry.
  static String soon(String title) => 'Bald: $title';

  static String dayLabel(int day) => 'Tag $day';

  static const rewardsTitle = 'Deine Belohnungen';

  /// What the reward line does, to a screen reader.
  static const openRewards = 'Belohnungen ansehen';

  // The Buddy's lines in a day's sheet.

  static const day1Line =
      'Willkommen an Tag 1! Hier ist dein erstes Rezept für dich.';

  static const day2Line = 'Tag 2! Hier ist ein Wissen-Häppchen für dich.';
  static const day2Body =
      'FODMAPs sind bestimmte Kohlenhydrate in Lebensmitteln. Was '
      'dahintersteckt, erklärt dieser Artikel kurz und knackig.';
  static const articleTitle = 'Low FODMAP kurz und knackig';
  static const articleSource = 'myfodmap.at';
  static const articleUrl =
      'https://www.myfodmap.at/low-fodmap-kurz-und-knackig';
  static const articleFailure = 'Der Artikel konnte nicht geöffnet werden.';

  static const day3Line = 'Tag 3! Hier ist ein Rezept für dich.';

  /// Right after „Nein, danke".
  static const day3AfterNoLine = 'Alles klar! Dann hier ein Rezept für dich.';

  static const day5Line =
      'Tag 5! Hier ist ein Rezept mit Zutaten, die du schon gegessen hast.';

  /// Below [day5Line]: the matched lines („Mit Karotte und Reis: …").
  static String day5Because(List<String> names) =>
      'Mit ${joinGerman(names)}: Die hast du an Tagen ohne schlechtes '
      'Bauchgefühl gegessen.';

  static const day5GenericLine =
      'Tag 5! Hier ist noch ein Rezept, das zu dir passt.';

  /// No „Morgen" promise: day 7 may need more Bauchgefühl entries too.
  static String day6Line(int gutFeelingsLeft) => gutFeelingsLeft > 0
      ? 'Noch ein Tag und $gutFeelingsLeft× Bauchgefühl, dann schau ich nach '
            'deinen ersten Mustern.'
      : 'Noch ein Tag, dann schau ich nach deinen ersten Mustern.';

  static const day6Body =
      'So sieht die Muster-Seite dann aus, hier mit ausgedachten Werten:';

  /// The label on the day-6 preview's fictional sample.
  static const example = 'Beispiel';

  /// A recipe reward while the fit is unchecked, or nothing is left to pick.
  static const noRecipe =
      'Rezepte, die zu dir passen, findest du unter Entdecken.';

  static const firstTipStarted =
      'Ich mach dir jetzt deinen ersten Tipp. Das dauert einen Moment ✨';
  static const firstTipFailed =
      'Dein erster Tipp hat gerade nicht geklappt. Die wöchentlichen Tipps '
      'bleiben eingeschaltet.';

  // Buttons.

  static const openRecipe = 'Rezept ansehen';
  static const toRecipes = 'Zu den Rezepten';
  static const readArticle = 'Artikel lesen';
  static const thanks = 'Danke!';
  static const okay = 'Okay';
  static const later = 'Später';
  static const toTips = 'Zu deinen Tipps';
  static const toPatterns = 'Muster ansehen';

  /// Day 4: one per user (`sayingFor`).
  static const sayings = [
    'Jeder Eintrag hilft mir, dich besser kennenzulernen.',
    'Schön, dass du dranbleibst!',
    'Kleine Schritte zählen. Du machst gerade jeden Tag einen.',
    'Dein Bauch und ich, wir lernen uns gerade kennen.',
    'Du machst das super. Ich bin gern dabei.',
    'Vier Tage geschafft! Ich freu mich auf die nächsten mit dir.',
  ];
}
