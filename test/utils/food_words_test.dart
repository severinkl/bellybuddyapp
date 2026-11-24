import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/food_words.dart';

/// The cases of core's `food_words` tests, kept in step with them:
/// bellybuddy-core `backend/tests/domain/test_tip_recipes.py`
/// (`test_food_words_name_the_food_whatever_the_spelling`,
/// `test_food_words_find_the_food_in_its_processed_form`,
/// `test_food_words_keep_other_foods_apart`; core #12, 04d17e8).
const _sameFood = [
  ('Zwiebeln', 'Zwiebel'),
  ('rote Zwiebel', 'Zwiebel'),
  ('Zwiebel, gehackt', 'Zwiebeln'),
  ('Rote Zwiebeln (fein gewürfelt)', 'zwiebel'),
  ('Tomaten', 'Tomate'),
  ('Gehackte Tomaten aus der Dose', 'Tomate'),
  ('Haselnüsse', 'Haselnuss'),
  ('Weiße Bohnen', 'Bohne'),
  ('Laktosefreie Milch', 'Milch'),
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
  ('Haferflocken (glutenfrei)', 'Hafer'),
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
      'Haferflocken (glutenfrei)': {'haf', 'haferflock'},
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

    test('the same key without food words still matches; blank never', () {
      expect(sameFood('寿司', ' 寿司 '), isTrue);
      expect(sameFood('', ''), isFalse);
      expect(sameFood('  ', ' '), isFalse);
      expect(sameFood('Reis', ''), isFalse);
    });
  });
}
