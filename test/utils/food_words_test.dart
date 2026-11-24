import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/food_words.dart';

/// Core's shared food-words cases (bellybuddy-core
/// `backend/tests/fixtures/recipes/food_words.json`, copied byte for byte;
/// both change together, core first): the case lists of its `food_words`
/// and `match_key` tests, and `names`, each name with its match key and its
/// sorted food words as core computes them.
final Map<String, dynamic> _shared =
    jsonDecode(File('test/fixtures/recipes/food_words.json').readAsStringSync())
        as Map<String, dynamic>;

/// The `[name, other]` pairs of the shared list [key].
List<(String, String)> _pairs(String key) => [
  for (final pair in _shared[key] as List)
    (pair[0] as String, pair[1] as String),
];

void main() {
  group("core's shared cases", () {
    test('match_key: the key core gives', () {
      final cases = _pairs('match_key');
      expect(cases, isNotEmpty);
      for (final (name, key) in cases) {
        expect(matchKey(name), key, reason: name);
      }
    });

    test('same_food: the same, non-empty food words', () {
      final cases = _pairs('same_food');
      expect(cases, isNotEmpty);
      for (final (name, same) in cases) {
        expect(foodWords(name), foodWords(same), reason: '$name = $same');
        expect(foodWords(name), isNotEmpty, reason: name);
      }
    });

    test('processed: the food in its processed form, or a part of it', () {
      final cases = _pairs('processed');
      expect(cases, isNotEmpty);
      for (final (processed, food) in cases) {
        expect(
          foodWords(processed).intersection(foodWords(food)),
          isNotEmpty,
          reason: '$processed is $food too',
        );
      }
    });

    test('apart: other foods share no word', () {
      final cases = _pairs('apart');
      expect(cases, isNotEmpty);
      for (final (name, other) in cases) {
        expect(
          foodWords(name).intersection(foodWords(other)),
          isEmpty,
          reason: '$name is not $other',
        );
      }
    });

    test('free_from: a free-from food has no food words', () {
      final names = (_shared['free_from'] as List).cast<String>();
      expect(names, isNotEmpty);
      for (final name in names) {
        expect(foodWords(name), isEmpty, reason: name);
      }
    });

    test("names: every name's key and food words, as core gives them", () {
      final names = _shared['names'] as Map<String, dynamic>;
      expect(names, isNotEmpty);
      for (final MapEntry(key: name, value: expected) in names.entries) {
        expect(matchKey(name), expected['key'], reason: name);
        expect(
          foodWords(name).toList()..sort(),
          expected['words'],
          reason: name,
        );
      }
    });
  });

  group('foodWords (the forms core gives)', () {
    // Each expected set is what core's `food_words` returns for the name.
    const forms = {
      'Zwiebelpulver': {'zwiebel', 'zwiebelpulv'},
      'Rote Zwiebeln (fein gewürfelt)': {'zwiebel'},
      'Gemüsebrühwürfel ohne Zwiebel und Knoblauch': {'gemusebruhwurfel'},
      'Bohnen ohne Salz': {'bohn'},
      'Knoblauch-Öl': {'knoblauchol'},
      'Öl mit Knoblauch': {'knoblauch', 'ol'},
      'Hühnereier': {'huhnerei'},
      'Haferflocken': {'haf', 'haferflock'},
      'Agavendicksaft': {'agav', 'agavendicksaft'},
      'Paprikapulver': {'paprikapulv'},
      'Milchreis': {'milchrei'},
      'Weizengrieß': {'weiz', 'weizengriess'},
      'Weißkohl': {'weisskohl'},
      'Obst nach Wahl': {'obst'},
      'Zehe': {'zeh'},
    };
    for (final MapEntry(key: name, value: words) in forms.entries) {
      test(name, () => expect(foodWords(name), words));
    }

    test('a name of qualifiers only keeps them', () {
      expect(foodWords('Frisch'), {'frisch'});
      expect(foodWords('Gehackt und gerieben'), {'gehackt', 'gerieb', 'und'});
    });

    test('folded like core: accents, a decomposed umlaut, a ligature', () {
      expect(foodWords('Crème fraîche'), {'crem', 'fraich'});
      expect(foodWords('Jalapeño'), {'jalapeno'});
      expect(foodWords('Müsli'), {'musli'});
      expect(foodWords('Müsli'), {'musli'});
      expect(foodWords('Pﬁrsich'), {'pfirsich'});
    });

    test('a name without letters a–z has none', () {
      expect(foodWords(''), isEmpty);
      expect(foodWords('  '), isEmpty);
      expect(foodWords('123 g'), {'g'});
      expect(foodWords('寿司'), isEmpty);
    });

    test("a FoodName's words cannot be changed", () {
      final words = FoodName('Zwiebeln').words;
      expect(() => words.add('x'), throwsUnsupportedError);
    });
  });

  group('foodWords: a free-from food has none (ruling 2026-11-24)', () {
    test('anywhere in the name, also after „ohne"', () {
      for (final name in [
        'Laktosefreimilch',
        'Glutenfreibrot',
        'Bio-laktosefreie Milch',
        'Glutenfreie Haferflocken',
        'GLUTENFREIE NUDELN',
        'Brot ohne glutenfreies Mehl',
      ]) {
        expect(foodWords(name), isEmpty, reason: name);
      }
    });
  });

  group('matchKey', () {
    test("Python's whitespace goes, other characters stay", () {
      expect(matchKey('Kokos\u00a0Milch\u2009(Dose)'), 'kokosmilch');
      expect(matchKey('Laktosefreie Milch (1,5 %)'), 'laktosefreiemilch');
      expect(matchKey('Milch 1,5 %'), 'milch1,5%');
      expect(matchKey('(Notiz)'), '');
    });
  });

  group('sameFood', () {
    test('a shared food word', () {
      expect(sameFood('eier', 'Ei'), isTrue);
      expect(sameFood('zwiebel', 'Zwiebelpulver'), isTrue);
      expect(sameFood('Rote Zwiebeln', 'zwiebel'), isTrue);
    });

    test('other foods are not', () {
      expect(sameFood('milch', 'Kokosmilch'), isFalse);
      expect(sameFood('eier', 'Eisbergsalat'), isFalse);
      expect(sameFood('zwiebel', 'Frühlingszwiebelgrün'), isFalse);
      expect(sameFood('reis', 'Milchreis'), isFalse);
    });

    test("a free-from food only by core's match key", () {
      expect(sameFood('Laktosefreie Milch', 'laktosefreie milch'), isTrue);
      expect(
        sameFood('Laktosefreie Milch', 'Laktosefreie Milch (1,5 %)'),
        isTrue,
      );
      expect(sameFood('Laktosefreie  Milch', 'Laktosefreie-Milch'), isTrue);
      expect(sameFood('Milch (laktosefrei)', 'milch (Laktosefrei)'), isTrue);
      expect(sameFood('Laktosefreie Milch', 'Milch'), isFalse);
      expect(sameFood('milch', 'Laktosefreie Milch'), isFalse);
      expect(sameFood('Milch (laktosefrei)', 'Milch'), isFalse);
      expect(sameFood('Milch', 'Milch (laktosefrei)'), isFalse);
      expect(sameFood('glutenfreies Brot', 'Brot'), isFalse);
    });

    test('the match key also joins what the words keep apart', () {
      expect(sameFood('Kokos Milch', 'Kokosmilch'), isTrue);
      expect(sameFood('Knoblauch-Öl', 'Knoblauchöl'), isTrue);
    });

    test('the same key without food words still matches; blank never', () {
      expect(sameFood('寿司', ' 寿司 '), isTrue);
      expect(sameFood('', ''), isFalse);
      expect(sameFood('  ', ' '), isFalse);
      expect(sameFood('Reis', ''), isFalse);
      expect(sameFood('(Notiz)', '(Notiz)'), isFalse);
    });
  });

  group('sameFood, not through processing (the day-5 copy)', () {
    bool strict(String a, String b) => sameFood(a, b, viaProcessing: false);

    test("core's processed pairs: the food, but not this way", () {
      final cases = _pairs('processed');
      for (final (processed, food) in cases) {
        expect(sameFood(processed, food), isTrue, reason: processed);
        expect(strict(processed, food), isFalse, reason: processed);
        expect(strict(food, processed), isFalse, reason: processed);
      }
    });

    test("core's same-food pairs stay the same", () {
      for (final (name, same) in _pairs('same_food')) {
        expect(strict(name, same), isTrue, reason: '$name = $same');
      }
    });

    test('plural, irregular plural and the same key: the same; a processed '
        'form or part: not', () {
      expect(strict('Eier', 'Ei'), isTrue);
      expect(strict('Rote Zwiebeln', 'zwiebel'), isTrue);
      expect(strict('Äpfel', 'Apfel'), isTrue);
      expect(strict('Apfelsäfte', 'Apfelsaft'), isTrue);
      expect(strict('Zwiebelpulver', 'zwiebelpulver'), isTrue);
      expect(strict('Apfel', 'Apfelsaft'), isFalse);
      expect(strict('Zwiebel', 'Zwiebelpulver'), isFalse);
      expect(strict('Knoblauch', 'Knoblauchzehen'), isFalse);
    });

    test('free-from foods as before: only by the key', () {
      expect(strict('Laktosefreie Milch', 'laktosefreie milch'), isTrue);
      expect(strict('Laktosefreie Milch', 'Milch'), isFalse);
    });
  });

  group('FoodName', () {
    test('its name, key and words', () {
      final zwiebeln = FoodName('Zwiebeln');
      expect(zwiebeln.name, 'Zwiebeln');
      expect(zwiebeln.key, 'zwiebeln');
      expect(zwiebeln.words, {'zwiebel'});
      expect(zwiebeln.isSame(FoodName('rote Zwiebel')), isTrue);
    });
  });

  group('foodGroups', () {
    test('the names of one food share a group, also through another', () {
      final groups = foodGroups([
        'zwiebel',
        'reis',
        'zwiebeln',
        'öl mit knoblauch',
        'rote zwiebel',
        'knoblauch',
        'öl',
        'milchreis',
      ]);
      expect(
        [
          for (final group in groups) {for (final food in group) food.name},
        ],
        unorderedEquals([
          {'zwiebel', 'zwiebeln', 'rote zwiebel'},
          {'reis'},
          {'öl mit knoblauch', 'knoblauch', 'öl'},
          {'milchreis'},
        ]),
      );
    });

    test('none for no names', () => expect(foodGroups(const []), isEmpty));
  });
}
