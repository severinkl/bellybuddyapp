import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/food_words.dart';

/// The cases of core's `food_words` tests, kept in step with them:
/// bellybuddy-core `backend/tests/domain/test_tip_recipes.py`
/// (`test_food_words_name_the_food_whatever_the_spelling`,
/// `test_food_words_find_the_food_in_its_processed_form`,
/// `test_food_words_keep_other_foods_apart`,
/// `test_a_free_from_food_has_no_food_words`; core #12, 04d17e8 and
/// dd3c42e, the free-from ruling of 2026-11-24).
const _sameFood = [
  ('Zwiebeln', 'Zwiebel'),
  ('rote Zwiebel', 'Zwiebel'),
  ('Zwiebel, gehackt', 'Zwiebeln'),
  ('Rote Zwiebeln (fein gewürfelt)', 'zwiebel'),
  ('Tomaten', 'Tomate'),
  ('Gehackte Tomaten aus der Dose', 'Tomate'),
  ('Haselnüsse', 'Haselnuss'),
  ('Weiße Bohnen', 'Bohne'),
  ('Gemüsebrühwürfel ohne Zwiebel und Knoblauch', 'Gemüsebrühwürfel'),
  // irregular plurals (the table), also at a compound's end
  ('Eier', 'Ei'),
  ('Eiern', 'Ei'),
  ('Rühreier', 'Rührei'),
  ('Hühnereier', 'Hühnerei'),
  ('Kräuter', 'Kraut'),
  ('Gemischte Kräuter', 'Kräuter'),
  ('Nüsse', 'Nuss'),
  ('Walnüssen', 'Walnuss'),
  ('Äpfel', 'Apfel'),
  ('Hühner', 'Huhn'),
  ('Maiskörner', 'Maiskorn'),
  ('Kürbisse', 'Kürbis'),
  ('Hokkaido-Kürbisse', 'Hokkaido-Kürbis'),
  ('Lachse', 'Lachs'),
  ('Gänse', 'Gans'),
];

const _processed = [
  ('Zwiebelpulver', 'Zwiebeln'),
  ('Knoblauchpulver', 'Knoblauch'),
  ('Knoblauchgranulat', 'Knoblauch'),
  ('Knoblauchsalz', 'Knoblauch'),
  ('Knoblauchzehen', 'Knoblauch'),
  ('Apfelsaft', 'Äpfel'),
  ('Zitronensaft', 'Zitrone'),
  ('Agavendicksaft', 'Agavensirup'),
  ('Weizenmehl', 'Weizen'),
  ('Weizengrieß', 'Weizen'),
  ('Haferflocken', 'Hafer'),
  ('Erdnussmus', 'Erdnüsse'),
  ('Erdnussbutter', 'Erdnuss'),
  ('Apfelmus', 'Apfel'),
  ('Tomatenmark', 'Tomaten'),
  ('Tamarindenpaste', 'Tamarinde'),
  ('Kürbispüree', 'Kürbis'),
  ('Vanilleextrakt', 'Vanilleschote'),
  ('Rote Chilischote', 'Chili'),
  ('Fenchelknolle', 'Fenchel'),
  ('Lauchstangen', 'Lauch'),
  ('Brokkoliröschen', 'Brokkoli'),
  ('Zwiebel-Pulver', 'Zwiebel'),
];

const _otherFoods = [
  ('Zwiebel', 'Frühlingszwiebelgrün'),
  ('Zwiebel', 'Frühlingszwiebel (nur das Grün)'),
  ('Knoblauch', 'Knoblauch-Öl'),
  ('rote Zwiebel', 'Rote Paprika'),
  ('Milch', 'Kokosmilch light'),
  ('Zwiebel', 'Gemüsebrühwürfel ohne Zwiebel und Knoblauch'),
  // compounds that are another food, also with the suffix allowlist and
  // the plural table
  ('Zwiebeln', 'Frühlingszwiebelgrün'),
  ('Zwiebelpulver', 'Frühlingszwiebel'),
  ('Knoblauch', 'Knoblauchöl'),
  ('Reis', 'Milchreis'), // the rice of a rice pudding stays a food of its own
  ('Milch', 'Milchreis'),
  ('Milch', 'Kokosmilch'),
  ('Mandeln', 'Mandelmilch'),
  ('Lauch', 'Schnittlauch'),
  ('Zwiebel', 'Schnittlauch'),
  ('Ei', 'Eisbergsalat'),
  ('Eier', 'Eisbergsalat'),
  ('Eier', 'Eiweißpulver'),
  ('Ei', 'Salbei'),
  ('Paprika', 'Paprikapulver'), // the spice, not the vegetable
  ('Kakao', 'Kakaobutter'),
  ('Kürbis', 'Kürbiskerne'),
  ('Apfel', 'Granatapfelsaft'),
  ('Apfel', 'Apfelessig'),
  ('Erdnuss', 'Erdnussöl'),
  ('Soja', 'Sojasprossen'),
  ('Mehl', 'Weizenmehl'),
  ('Saft', 'Apfelsaft'),
  // a free-from food is another food (the Tausch-Tipp Milch → laktosefreie
  // Milch; ruling of 2026-11-24)
  ('Milch', 'Laktosefreie Milch'),
  ('Milch', 'Milch (laktosefrei)'),
  ('Brot', 'Glutenfreies Brot'),
  ('Brot', 'Brot (glutenfrei)'),
  ('Hafer', 'Haferflocken (glutenfrei)'),
  ('Joghurt', 'Laktosefrei-Joghurt'),
];

/// Core's `test_match_key` (dd3c42e).
const _matchKeys = {
  'Knoblauchöl': 'knoblauchol',
  'Knoblauch-Öl': 'knoblauchol',
  '  Laktosefreie   Milch ': 'laktosefreiemilch',
  'Gemüsebrühe (low-FODMAP)': 'gemusebruhe',
  // a bracketed free-from note stays: lactose-free milk is not milk
  'Milch (laktosefrei)': 'milchlaktosefrei',
  'Brot (Glutenfrei)': 'brotglutenfrei',
  'Frühlingszwiebel (nur das Grün)': 'fruhlingszwiebel',
  'Weißkohl': 'weisskohl',
};

/// Core's `test_a_free_from_food_has_no_food_words`.
const _freeFromFoods = [
  'Laktosefreie Milch',
  'laktosefreier Joghurt',
  'Laktosefreies Eis',
  'mit laktosefreiem Quark',
  'aus laktosefreien Milchprodukten',
  'Milch, laktosefrei',
  'Milch (laktosefrei)',
  'Laktosefrei-Joghurt',
  'Glutenfreies Brot',
  'Brot (glutenfrei)',
  'Weizenfreie Nudeln',
  'Fruktosefreier Sirup',
  'Fructosefreier Sirup',
];

void main() {
  group('foodWords (core cases)', () {
    test('name the food whatever the spelling', () {
      for (final (name, same) in _sameFood) {
        expect(foodWords(name), foodWords(same), reason: '$name = $same');
        expect(foodWords(name), isNotEmpty, reason: name);
      }
    });

    test('find the food in its processed form', () {
      for (final (processed, food) in _processed) {
        expect(
          foodWords(processed).intersection(foodWords(food)),
          isNotEmpty,
          reason: '$processed is $food too',
        );
      }
    });

    test('keep other foods apart', () {
      for (final (name, other) in _otherFoods) {
        expect(
          foodWords(name).intersection(foodWords(other)),
          isEmpty,
          reason: '$name is not $other',
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

    test('the same set again, which cannot be changed', () {
      final words = foodWords('Zwiebeln');
      expect(foodWords('Zwiebeln'), same(words));
      expect(() => words.add('x'), throwsUnsupportedError);
    });
  });

  group('foodWords: a free-from food has none (ruling 2026-11-24)', () {
    test('core cases: any inflection, a bracketed note, a compound', () {
      for (final name in _freeFromFoods) {
        expect(foodWords(name), isEmpty, reason: name);
      }
    });

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
    test('core cases', () {
      for (final MapEntry(key: name, value: key) in _matchKeys.entries) {
        expect(matchKey(name), key, reason: name);
      }
    });

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

  group('FoodName', () {
    test('read once: the same instance for the same name', () {
      final zwiebeln = FoodName.of('Zwiebeln');
      expect(FoodName.of('Zwiebeln'), same(zwiebeln));
      expect(zwiebeln.name, 'Zwiebeln');
      expect(zwiebeln.key, 'zwiebeln');
      expect(zwiebeln.words, {'zwiebel'});
      expect(zwiebeln.isSame(FoodName.of('rote Zwiebel')), isTrue);
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
