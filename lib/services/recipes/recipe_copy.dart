import '../../utils/german_list.dart';

/// German copy for how a collection recipe fits the user: observations
/// from their intolerances, never a diagnosis or a health claim.
abstract final class RecipeCopy {
  /// The badge of a recipe without kritisch ingredients.
  static const fits = 'Passt zu dir';

  /// The badge of a recipe with [n] kritisch ingredients.
  static String kritisch(int n) => n == 1
      ? '1 Zutat ist für dich kritisch'
      : '$n Zutaten sind für dich kritisch';

  /// The badge for intolerances the catalog can't judge: „Histamin bitte
  /// selbst prüfen".
  static String selfCheck(List<String> names) =>
      '${joinGerman(names)} bitte selbst prüfen';

  /// Below a kritisch line: „wegen Gluten und Weizen".
  static String because(List<String> names) => 'wegen ${joinGerman(names)}';

  /// After a kritisch line's name.
  static const kritischSuffix = '— für dich kritisch';

  /// After an unmapped line's name, while it can't be judged.
  static const notInCatalog = 'nicht im Katalog';

  /// The Buddy swapped this ingredient (after the new name).
  static const swapped = 'getauscht';

  /// The Buddy left this ingredient out (after its struck name).
  static const removed = 'weggelassen';

  /// Screen-reader fragments of an ingredient line and a step.
  static String swappedSemantics(String from, String to) =>
      '$from getauscht gegen $to';
  static const removedSemantics = 'weggelassen';
  static const kritischSemantics = 'für dich kritisch';
  static const fitsSemantics = 'passt';
  static const stepChanged = 'geändert';

  /// The tags on a recipe card's picture.
  static const tagSaved = 'Gemerkt';
  static const tagAdapted = 'Angepasst';

  /// Below „Für mich anpassen": which ingredients the Buddy swaps.
  static String adaptHint(List<String> names) =>
      'Ich tausche ${joinGerman(names)} und schreibe die Schritte passend um.';

  /// Below the „Passt zu mir" toggle: what it can't check.
  static String selfCheckFilter(List<String> names) =>
      '${joinGerman(names)} kann ich nicht prüfen, bitte schau da selbst.';
}
