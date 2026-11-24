import 'ingredient_key.dart';

/// Whether [a] and [b] name the same food: the same [ingredientKey] (not
/// blank), or a shared word of [foodWords] („Eier" and „Ei",
/// „Zwiebelpulver" and „Zwiebeln"; not „Kokosmilch" and „Milch"). How the
/// app matches recipe lines against foods, like core.
bool sameFood(String a, String b) {
  final key = ingredientKey(a);
  return (key.isNotEmpty && key == ingredientKey(b)) ||
      foodWords(a).any(foodWords(b).contains);
}

/// The words of [name] that name the food, in their base form: core's
/// `food_words` (bellybuddy-core `backend/app/domain/tip_recipes.py`, core
/// #12), ported step by step and table by table, so the app and core agree
/// on which recipe line is which food. Two names are the same food when
/// their sets share a word.
///
/// The name is folded ([_fold]), without a bracketed note or an „ohne …"
/// tail, a hyphenated word read joined („Knoblauch-Öl" is „knoblauchol"),
/// and without qualifiers ([_qualifiers]; a name of qualifiers only keeps
/// them). A compound ending in a processing end ([_processedEnds]) also
/// names the food before it. „Zwiebeln", „rote Zwiebel", „Zwiebel,
/// gehackt" and „Zwiebelpulver" share „zwiebel", „Eier" and „Ei" share
/// „ei"; „Frühlingszwiebelgrün", „Kokosmilch" and „Eisbergsalat" are words
/// of their own. Empty for a name without a letter a–z, and for a
/// free-from food ([_freeFrom]): „Laktosefreie Milch" is no „Milch", it
/// matches its own name only (by its `ingredientKey`, [sameFood]).
///
/// Known limits, precision first (a missed spelling only costs a ranking
/// point or a named line; a wrong match would name a food the user did not
/// eat):
/// - a compound is its own food unless it ends in a processing end:
///   „Schnittlauch" is no onion, „Milchreis" neither rice nor milk;
/// - only the end of a compound is read: „Hühnerbrühe" is no chicken;
/// - irregular plurals outside [_irregular] are missed („Ananasse");
/// - an unknown adjective before a food is a word of its own.
///
/// The same unmodifiable set for the same name: the app compares the same
/// few hundred names (the collection's lines, the diary's ingredients) on
/// every ranking, so the sets are kept (up to [_memoLimit] names).
Set<String> foodWords(String name) {
  final known = _memo[name];
  if (known != null) return known;
  if (_memo.length >= _memoLimit) _memo.clear();
  return _memo[name] = Set.unmodifiable(_foodWords(name));
}

final _memo = <String, Set<String>>{};

/// More names than the collection and a diary hold; past it the kept sets
/// start over.
const _memoLimit = 4096;

Set<String> _foodWords(String name) {
  if (_freeFrom.hasMatch(_fold(name))) return {};
  final folded = _fold(name.replaceAll(_note, ' '));
  final ohne = _ohne.firstMatch(folded);
  final text = ohne == null ? folded : folded.substring(0, ohne.start);
  final words = <String>[];
  for (final match in _word.allMatches(text)) {
    final word = match[0]!.replaceAll('-', '');
    words.add(_baseForm(word));
    if (_processedFood(word) case final food?) words.add(_baseForm(food));
  }
  final named = {
    for (final word in words)
      if (!_qualifiers.contains(word)) word,
  };
  return named.isNotEmpty ? named : words.toSet();
}

/// „laktosefrei", „glutenfrei", „weizenfrei", „fruktosefrei" (also
/// „fructosefrei"), folded, in any inflection and anywhere in the name, a
/// bracketed note and an „ohne …" tail included („Laktosefreie Milch",
/// „Laktosefrei-Joghurt", „Brot (glutenfrei)"): a free-from food is another
/// food than the plain one (core's `FREE_FROM`, dd3c42e).
final _freeFrom = RegExp(r'(?:laktose|gluten|weizen|fru[kc]tose)frei');

/// A bracketed note („Gemüsebrühe (low-FODMAP)").
final _note = RegExp(r'\([^)]*\)');

/// „ohne" as a whole word (Python's `\bohne\b` on a folded name).
final _ohne = RegExp(r'(?<![\p{L}\p{N}_])ohne(?![\p{L}\p{N}_])', unicode: true);

/// A word, hyphenated parts included (core's `allergens.WORD`).
final _word = RegExp(r'[a-z]+(?:-[a-z]+)*');

/// A combining mark, as a decomposed „ü" carries it.
final _mark = RegExp(r'\p{M}', unicode: true);

/// [name] as core's `allergens.fold` makes it: lower case, ß as ss, and
/// every letter as its NFKD form without combining marks („Crème" is
/// „creme").
String _fold(String name) => name
    .toLowerCase()
    .replaceAll('ß', 'ss')
    .split('')
    .map((char) => _folded[char] ?? char)
    .join()
    .replaceAll(_mark, '');

/// The letters NFKD turns into letters a–z once their marks are dropped,
/// by what they become: Latin-1 Supplement, Latin Extended-A, -B and
/// Additional, and the Latin ligatures, lower case (generated with Python's
/// `unicodedata`). Dart has no NFKD; any other character stays and, not
/// being a–z, separates words, as in core.
final Map<String, String> _folded = {
  for (final MapEntry(key: letter, value: forms) in _accented.entries)
    for (final form in forms.split('')) form: letter,
  'ĳ': 'ij',
  'ǆ': 'dz',
  'ǉ': 'lj',
  'ǌ': 'nj',
  'ǳ': 'dz',
  'ﬀ': 'ff',
  'ﬁ': 'fi',
  'ﬂ': 'fl',
  'ﬃ': 'ffi',
  'ﬄ': 'ffl',
  'ﬅ': 'st',
  'ﬆ': 'st',
};

const _accented = {
  'a': 'àáâãäåāăąǎǟǡǻȁȃȧḁạảấầẩẫậắằẳẵặ',
  'b': 'ḃḅḇ',
  'c': 'çćĉċčḉ',
  'd': 'ďḋḍḏḑḓ',
  'e': 'èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệ',
  'f': 'ḟ',
  'g': 'ĝğġģǧǵḡ',
  'h': 'ĥȟḣḥḧḩḫẖ',
  'i': 'ìíîïĩīĭįǐȉȋḭḯỉị',
  'j': 'ĵǰ',
  'k': 'ķǩḱḳḵ',
  'l': 'ĺļľḷḹḻḽ',
  'm': 'ḿṁṃ',
  'n': 'ñńņňǹṅṇṉṋ',
  'o': 'òóôõöōŏőơǒǫǭȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợ',
  'p': 'ṕṗ',
  'r': 'ŕŗřȑȓṙṛṝṟ',
  's': 'śŝşšſșṡṣṥṧṩẛ',
  't': 'ţťțṫṭṯṱẗ',
  'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữự',
  'v': 'ṽṿ',
  'w': 'ŵẁẃẅẇẉẘ',
  'x': 'ẋẍ',
  'y': 'ýÿŷȳẏẙỳỵỷỹ',
  'z': 'źżžẑẓẕ',
};

/// A folded word in the form [foodWords] compares: an irregular plural's
/// singular ([_irregular]), a word ending in one of those singulars as it
/// is (else „Huhn" would lose its n, „Lachs" its s), else [_stem].
String _baseForm(String word) {
  for (final MapEntry(key: plural, value: singular) in _irregularLongestFirst) {
    if (word.endsWith(plural)) {
      return word.substring(0, word.length - plural.length) + singular;
    }
  }
  return _singulars.any(word.endsWith) ? word : _stem(word);
}

/// Irregular plurals, folded, as their singular: „Eier" is „Ei",
/// „Rühreier" „Rührei", „Maiskörner" „Maiskorn". Umlaut plurals need no
/// entry: folding makes „Äpfel" „apfel"; „Kräuter" and „Nüsse" are here
/// for their dative.
const _irregular = {
  'eier': 'ei',
  'eiern': 'ei',
  'krauter': 'kraut',
  'krautern': 'kraut',
  'nusse': 'nuss',
  'nussen': 'nuss',
  'huhner': 'huhn',
  'huhnern': 'huhn',
  'korner': 'korn',
  'kornern': 'korn',
  'kurbisse': 'kurbis',
  'kurbissen': 'kurbis',
  'lachse': 'lachs',
  'lachsen': 'lachs',
  'ganse': 'gans',
  'gansen': 'gans',
};

final _irregularLongestFirst = _irregular.entries.toList()
  ..sort((a, b) => b.key.length - a.key.length);

final _singulars = _irregular.values.toSet();

/// Plural and adjective endings, in the order they are tried: „Zwiebeln"
/// is „Zwiebel", „Tomaten" „Tomate", „rote" and „roter" „rot".
const _endings = ['en', 'er', 'es', 'em', 'e', 'n', 's'];

/// A folded word without one ending of [_endings], when 3 letters stay
/// („nuss" keeps its „ss": „Nüsse" is „Nuss").
String _stem(String word) {
  for (final ending in _endings) {
    if (word.endsWith(ending) &&
        word.length - ending.length >= 3 &&
        !(ending == 's' && word.endsWith('ss'))) {
      return word.substring(0, word.length - ending.length);
    }
  }
  return word;
}

/// What a food becomes by processing, or one of its parts, as the end of a
/// compound („Zwiebelpulver", „Apfelsaft", „Weizenmehl", „Knoblauchzehen"):
/// the compound is that food too. An allowlist, precision first: no oil
/// („Knoblauchöl" is low-FODMAP), milk („Kokosmilch"), vinegar
/// („Apfelessig"), starch, seeds („Kürbiskerne"), sprouts („Sojasprossen")
/// or greens („Frühlingszwiebelgrün").
const _processedEnds = [
  // processed
  'pulver',
  'granulat',
  'salz',
  'saft',
  'dicksaft',
  'sirup',
  'mus',
  'mark',
  'paste',
  'puree',
  'butter',
  'mehl',
  'griess',
  'flocken',
  'extrakt',
  'konzentrat',
  // a part of the food
  'zehe',
  'zehen',
  'schote',
  'schoten',
  'knolle',
  'knollen',
  'stange',
  'stangen',
  'roschen',
];

/// Longest first, so „dicksaft" wins over „saft".
final _processedLongestFirst = [..._processedEnds]
  ..sort((a, b) => b.length - a.length);

/// Compounds with a processing end that are not the food before it: paprika
/// the spice is not the vegetable, cocoa butter not cocoa.
const _notProcessed = {'paprikapulver', 'kakaobutter'};

/// The food of a folded compound [word] that ends in a processing end
/// ([_processedEnds]), with at least 3 letters before it („zwiebelpulver"
/// is „zwiebel"); null for any other word.
String? _processedFood(String word) {
  if (_notProcessed.contains(word)) return null;
  for (final end in _processedLongestFirst) {
    if (word.endsWith(end)) {
      final food = word.length - end.length;
      return food >= 3 ? word.substring(0, food) : null;
    }
  }
  return null;
}

/// Words that say how a food is (colour, cut, cooked, kept, free of) or
/// the small words of „aus der Dose", „nach Wahl": not the food. Base
/// forms; their endings are folded like a food's.
const _qualifierWords = '''
rot grün gelb weiß schwarz braun dunkel hell bunt
frisch roh gekocht gegart gebacken gebraten gedünstet gegrillt gehackt gemahlen gerieben getrocknet geröstet
geräuchert gepufft gemischt gewürfelt geschält geschnitten gefroren tiefgekühlt eingelegt püriert stückig
ganz halbiert fein grob klein groß mittelgroß jung reif mild scharf
vegan vegetarisch bio light natur tk
aus der die das dem den des ein eine dose glas packung nach wahl mit und oder von vom zum zur für in im nur
''';

/// [_qualifierWords] folded, each as it is and in its [_baseForm].
final _qualifiers = {
  for (final word in _fold(_qualifierWords).trim().split(RegExp(r'\s+'))) ...{
    word,
    _baseForm(word),
  },
};
