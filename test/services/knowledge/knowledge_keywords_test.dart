import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/symptom_options.dart';
import 'package:belly_buddy/services/knowledge/knowledge_keywords.dart';

void main() {
  test(
    'every intoleranceOptions value has keywords; every symptom of the spec map has keywords; a kSymptomOptions value outside the map gives no signal',
    () {
      for (final value in AppConstants.intoleranceOptions) {
        expect(
          KnowledgeKeywords.intolerances[value],
          isNotEmpty,
          reason: value,
        );
      }
      expect(
        KnowledgeKeywords.intolerances.keys.toSet(),
        AppConstants.intoleranceOptions.toSet(),
      );
      const specSymptoms = [
        'Durchfall',
        'Verstopfung',
        'Blähungen',
        'Blähbauch',
        'Völlegefühl',
        'Bauchschmerzen',
        'Krämpfe',
        'Sodbrennen',
        'Übelkeit',
        'Stress',
      ];
      expect(KnowledgeKeywords.symptoms.keys.toList(), specSymptoms);
      for (final s in specSymptoms) {
        expect(KnowledgeKeywords.symptoms[s], isNotEmpty, reason: s);
      }
      for (final s in [
        ...kSymptomOptions.map((o) => o.value),
        ...AppConstants.gutFeelingSymptoms,
      ]) {
        expect(KnowledgeKeywords.symptoms[s], isNotEmpty, reason: s);
      }
      // A stored value the map doesn't know has no keywords.
      expect(KnowledgeKeywords.symptoms['Kopfschmerzen'], isNull);
      // Every group points at an intolerance's keywords.
      for (final group in KnowledgeKeywords.ingredientGroups.keys) {
        expect(KnowledgeKeywords.intolerances[group], isNotEmpty);
      }
      // The verbatim map of spec §4.2.
      expect(KnowledgeKeywords.intolerances, {
        'Laktose': ['laktose', 'milchzucker'],
        'Gluten': ['gluten'],
        'Weizen': ['weizen', 'gluten'],
        'Fruktose': ['fruktose', 'fructose', 'fruchtzucker'],
        'Histamin': ['histamin'],
        'Sorbit': ['sorbit', 'zuckeralkohol'],
        'Nüsse': ['nuss', 'nüsse'],
        'Eier': ['eier'],
        'Soja': ['soja'],
      });
      expect(KnowledgeKeywords.symptoms, {
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
      });
      expect(KnowledgeKeywords.ingredientGroups, {
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
      });
    },
  );

  test('no disease names in any keyword', () {
    final all = [
      ...KnowledgeKeywords.intolerances.values.expand((k) => k),
      ...KnowledgeKeywords.symptoms.values.expand((k) => k),
      ...KnowledgeKeywords.ingredientGroups.values.expand((k) => k),
    ];
    for (final k in all) {
      expect(k, k.toLowerCase());
      for (final disease in ['sibo', 'leaky', 'zöliakie', 'reizdarm']) {
        expect(k.contains(disease), isFalse, reason: k);
      }
    }
  });

  test(
    'word start: "verstopf" matches "Reizdarm Typ: Verstopfung", "Blähung" matches "Unangenehme Blähungen"; "stress" does not match "Distress"',
    () {
      expect(
        KnowledgeKeywords.matchesAtWordStart(
          'Reizdarm Typ: Verstopfung',
          'verstopf',
        ),
        isTrue,
      );
      expect(
        KnowledgeKeywords.matchesAtWordStart(
          'Unangenehme Blähungen',
          'Blähung',
        ),
        isTrue,
      );
      expect(
        KnowledgeKeywords.matchesAtWordStart('Distress im Alltag', 'stress'),
        isFalse,
      );
      expect(
        KnowledgeKeywords.matchesAtWordStart('STRESS und Bauch', 'stress'),
        isTrue,
      );
      expect(
        KnowledgeKeywords.matchesAtWordStart(
          'Die Darm-Hirn-Achse',
          'darm-hirn',
        ),
        isTrue,
      );
      // ä is a letter: „Gebäck" holds no word starting with „äck".
      expect(KnowledgeKeywords.matchesAtWordStart('Gebäck', 'äck'), isFalse);
      expect(
        KnowledgeKeywords.matchesAtWordStart('ÜBELKEIT', 'übelkeit'),
        isTrue,
      );
      expect(KnowledgeKeywords.matchesWholeWord('Reis mit Ei', 'reis'), isTrue);
      expect(
        KnowledgeKeywords.matchesWholeWord('Reiswaffeln', 'reis'),
        isFalse,
      );
      expect(KnowledgeKeywords.matchesWholeWord('Mais-Reis', 'reis'), isTrue);
      expect(
        KnowledgeKeywords.matchesWholeWord('Süßkartoffel', 'süß'),
        isFalse,
      );
    },
  );

  test('group prefixes start a word', () {
    expect(KnowledgeKeywords.groupOf('Milch'), 'Laktose');
    expect(KnowledgeKeywords.groupOf('Hafermilch'), isNull);
    expect(KnowledgeKeywords.groupOf('Vollkornbrot'), isNull);
    expect(KnowledgeKeywords.groupOf('Brot, hell'), 'Gluten');
    expect(KnowledgeKeywords.groupOf('Griechischer Joghurt'), 'Laktose');
    expect(KnowledgeKeywords.groupOf('Apfelmus'), 'Fruktose');
    expect(KnowledgeKeywords.groupOf('Reis'), isNull);
  });
}
