/// The keywords „Für dich" matches articles with (title + teaser), all
/// lower case. No disease names, so a match never suggests a condition.
abstract final class KnowledgeKeywords {
  /// A profile intolerance (`AppConstants.intoleranceOptions`) → keywords.
  static const Map<String, List<String>> intolerances = {
    'Laktose': ['laktose', 'milchzucker'],
    'Gluten': ['gluten'],
    'Weizen': ['weizen', 'gluten'],
    'Fruktose': ['fruktose', 'fructose', 'fruchtzucker'],
    'Histamin': ['histamin'],
    'Sorbit': ['sorbit', 'zuckeralkohol'],
    'Nüsse': ['nuss', 'nüsse'],
    'Eier': ['eier'],
    'Soja': ['soja'],
  };

  /// A symptom (the profile values of `kSymptomOptions`, the four tracker
  /// symptoms) or 'Stress' → keywords.
  static const Map<String, List<String>> symptoms = {
    'Durchfall': ['durchfall'],
    'Verstopfung': ['verstopf'],
    'Blähungen': ['blähung'],
    'Blähbauch': ['blähbauch', 'blähung'],
    'Völlegefühl': ['völlegefühl'],
    'Bauchschmerzen': ['bauchschmerz'],
    'Krämpfe': ['krampf', 'krämpf'],
    'Sodbrennen': ['sodbrennen'],
    'Übelkeit': ['übelkeit'],
    'Stress': ['stress', 'darm-hirn'],
  };

  /// An [intolerances] key → the prefixes that, starting a word of a Muster
  /// item's name, put the item in that group („Hafermilch" starts no word
  /// with „milch").
  static const Map<String, List<String>> ingredientGroups = {
    'Laktose': ['milch', 'joghurt', 'sahne', 'käse', 'quark', 'topfen'],
    'Gluten': [
      'brot',
      'nudel',
      'pasta',
      'weizen',
      'dinkel',
      'semmel',
      'brötchen',
    ],
    'Fruktose': ['apfel', 'birne', 'honig', 'mango'],
  };

  /// The category Muster signals never match.
  static const recipeCategory = 'Rezepte';

  /// Whether [keyword] starts a word of [text]: case-insensitive, a word
  /// being a run of Unicode letters and digits.
  static bool matchesAtWordStart(String text, String keyword) =>
      _find(text, keyword, wholeWord: false);

  /// Whether [word] is a whole word of [text], case-insensitive.
  static bool matchesWholeWord(String text, String word) =>
      _find(text, word, wholeWord: true);

  /// The first [ingredientGroups] key with a prefix starting a word of
  /// [ingredientName]; null when none does.
  static String? groupOf(String ingredientName) {
    for (final MapEntry(key: group, value: prefixes)
        in ingredientGroups.entries) {
      if (prefixes.any((p) => matchesAtWordStart(ingredientName, p))) {
        return group;
      }
    }
    return null;
  }

  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static bool _find(String text, String keyword, {required bool wholeWord}) {
    final haystack = text.toLowerCase(), needle = keyword.toLowerCase();
    if (needle.isEmpty) return false;
    bool isWordChar(int i) => _wordChar.hasMatch(haystack[i]);
    for (
      var i = haystack.indexOf(needle);
      i != -1;
      i = haystack.indexOf(needle, i + 1)
    ) {
      if (i > 0 && isWordChar(i - 1)) continue;
      final end = i + needle.length;
      if (wholeWord && end < haystack.length && isWordChar(end)) continue;
      return true;
    }
    return false;
  }
}
