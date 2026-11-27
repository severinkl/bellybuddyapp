import '../../utils/gut_feeling_rating.dart';
import 'daily_review_rules.dart';

/// German copy of the daily review, in the Buddy's voice.
abstract final class DailyReviewCopy {
  static String title(ReviewDay day) => day.yesterday
      ? 'Dein Rückblick auf gestern 🌙'
      : 'Dein Tagesrückblick 🌙';

  static String meals(int count, {required bool yesterday}) =>
      '${yesterday ? 'Gestern' : 'Heute'} hast du $count '
      '${count == 1 ? 'Mahlzeit' : 'Mahlzeiten'} eingetragen.';

  static String gut(GutFeelingRatingLevel level) =>
      'Dein Bauchgefühl zuletzt: ${level.label}.';

  static const String gutHard = 'Ich bin für dich da. 💛';
  static const String gutAsk = 'Magst du noch dein Bauchgefühl eintragen?';
  static const String gutAskButton = 'Bauchgefühl eintragen';

  static String alternative(
    String ingredient,
    String replacement, {
    required bool yesterday,
  }) =>
      'Statt $ingredient könntest du ${yesterday ? 'heute' : 'morgen'} '
      '$replacement probieren.';

  static String recent(String ingredient, int n) =>
      '$ingredient war in $n deiner Mahlzeiten der letzten zwei Wochen.';

  static const String tryIt = 'Probiere ich';
  static const String skip = 'Passt nicht für mich';
  static const String saved =
      'Gemerkt! Du findest es unter Entdecken › Alternativen.';
  static const String savedOpen = 'Ansehen';

  static String none({required bool yesterday}) => yesterday
      ? 'Für heute hab ich keine Alternative für dich.'
      : 'Für morgen hab ich keine Alternative für dich. Genieß deinen Abend!';

  static const String locked =
      'Für morgen hätte ich eine Alternative für dich.';
  static const String upsell = 'Mehr erfahren';
  static const String failed =
      'Das hat nicht geklappt. Versuch es später noch einmal.';
  static const String close = 'Schließen';

  /// The Buddy's hero line while the card waits below.
  static const String cueLine =
      'Magst du kurz auf deinen Tag schauen? Er wartet gleich unter mir. 🌙';

  static String notificationBody(String? buddyName) =>
      (buddyName == null || buddyName.trim().isEmpty)
      ? '🌙 Dein Tagesrückblick ist da.'
      : '🌙 $buddyName hat auf deinen Tag geschaut. '
            'Dein Tagesrückblick ist da.';
}
