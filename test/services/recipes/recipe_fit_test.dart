import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/intolerance_rules.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';

import '../../helpers/fixtures.dart';

final _rules = testIntoleranceRules();

RecipeFit _fit(
  List<RecipeIngredient> lines,
  List<String>? intolerances, {
  bool withRules = true,
}) => fitOf(
  testRecipe(ingredients: lines),
  rules: withRules ? _rules : null,
  intolerances: intolerances,
);

/// The mark per line name.
Map<String, LineMark> _marks(RecipeFit fit) => {
  for (final l in fit.lines) l.line.name: l.mark,
};

final _reis = testLine('Reis');
final _quark = testLine(
  'Quark',
  fodmaps: const FodmapFlags(lactose: true),
  allergens: {'milch'},
);
final _joghurt = testLine('Laktosefreier Joghurt', allergens: {'milch'});
final _parmesan = testLine(
  'Parmesan',
  fodmaps: const FodmapFlags(lactose: true),
  allergens: {'milch'},
  lowAtAmount: true,
);
final _butter = testLine('Butter', allergens: {'milch'});
final _knoblauch = testLine(
  'Knoblauch',
  fodmaps: const FodmapFlags(fructans: true),
);
final _dinkelmehl = testLine(
  'Dinkelmehl',
  fodmaps: const FodmapFlags(fructans: true),
  allergens: {'gluten', 'weizen'},
  lowAtAmount: true,
);
final _weizenmehl = testLine(
  'Weizenmehl',
  fodmaps: const FodmapFlags(fructans: true),
  allergens: {'gluten', 'weizen'},
);
final _honig = testLine('Honig', fodmaps: const FodmapFlags(fructose: true));
final _drachenfrucht = testLine('Drachenfrucht', mapped: false);

void main() {
  group('fitOf', () {
    test('Laktose', () {
      final fit = _fit([_quark, _joghurt, _parmesan, _butter], ['Laktose']);

      expect(fit.checked, isTrue);
      expect(fit.lines.map((l) => l.line), [
        _quark,
        _joghurt,
        _parmesan,
        _butter,
      ]);
      expect(_marks(fit), {
        'Quark': LineMark.kritisch,
        'Laktosefreier Joghurt': LineMark.fits,
        'Parmesan': LineMark.fits,
        'Butter': LineMark.fits,
      });
      expect(fit.lines.first.because, ['Laktose']);
      expect(fit.lines.skip(1).map((l) => l.because), everyElement(isEmpty));
      expect(fit.kritisch.map((l) => l.line), [_quark]);
      expect(fit.kritischCount, 1);
      expect(fit.badge, const KritischBadge(1));
      expect(fit.badge!.label, '1 Zutat ist für dich kritisch');
      expect(fit.passtZuMir, isFalse);
    });

    test('Gluten is allergen-only', () {
      final fit = _fit([_knoblauch, _dinkelmehl], ['Gluten']);

      expect(_marks(fit), {
        'Knoblauch': LineMark.fits,
        'Dinkelmehl': LineMark.kritisch,
      });
      expect(fit.kritisch.single.because, ['Gluten']);
    });

    test('Weizen', () {
      final fit = _fit([_knoblauch, _dinkelmehl, _reis], ['Weizen']);

      // Fructans count unless the amount is low; allergens always.
      expect(_marks(fit), {
        'Knoblauch': LineMark.kritisch,
        'Dinkelmehl': LineMark.kritisch,
        'Reis': LineMark.fits,
      });
      expect(fit.kritisch.map((l) => l.because), [
        ['Weizen'],
        ['Weizen'],
      ]);
    });

    test('Gluten and Weizen hit one line', () {
      final fit = _fit([_weizenmehl, _reis], ['Gluten', 'Weizen']);

      expect(fit.kritischCount, 1);
      expect(fit.kritisch.single.line, _weizenmehl);
      expect(fit.kritisch.single.because, ['Gluten', 'Weizen']);
      expect(fit.badge!.label, '1 Zutat ist für dich kritisch');

      // In profile order.
      final reversed = _fit([_weizenmehl], ['Weizen', 'Gluten']);
      expect(reversed.kritisch.single.because, ['Weizen', 'Gluten']);
    });

    test('Histamin only', () {
      final fit = _fit([_reis, _honig, _drachenfrucht], ['Histamin']);

      expect(fit.kritischCount, 0);
      // No ✓: it would read like a verdict on Histamin.
      expect(fit.lines.map((l) => l.mark), everyElement(LineMark.neutral));
      expect(fit.selfCheck, ['Histamin']);
      expect(fit.judged, isTrue);
      expect(fit.badge, const SelfCheckBadge(['Histamin']));
      expect(fit.badge!.label, 'Histamin bitte selbst prüfen');
      expect(fit.passtZuMir, isTrue);
    });

    test('Histamin and Fruktose', () {
      final fit = _fit([_reis, _honig], ['Histamin', 'Fruktose']);

      expect(_marks(fit), {
        'Reis': LineMark.neutral,
        'Honig': LineMark.kritisch,
      });
      expect(fit.kritisch.single.because, ['Fruktose']);
      expect(fit.selfCheck, ['Histamin']);
      expect(fit.badge, const KritischBadge(1));
      expect(fit.passtZuMir, isFalse);
    });

    test('Laktose and Histamin', () {
      final fit = _fit(
        [_quark, _joghurt, _drachenfrucht],
        ['Laktose', 'Histamin'],
      );

      expect(_marks(fit), {
        'Quark': LineMark.kritisch,
        'Laktosefreier Joghurt': LineMark.neutral,
        'Drachenfrucht': LineMark.unknown,
      });
      expect(fit.kritisch.single.because, ['Laktose']);
      expect(fit.badge, const KritischBadge(1));

      // Nothing kritisch: still no ✓, and the self-check badge.
      final calm = _fit([_joghurt, _reis], ['Laktose', 'Histamin']);
      expect(calm.lines.map((l) => l.mark), everyElement(LineMark.neutral));
      expect(calm.badge, const SelfCheckBadge(['Histamin']));
      expect(calm.passtZuMir, isTrue);
    });

    test('no intolerances', () {
      final fit = _fit([_reis, _drachenfrucht, _quark], const []);

      expect(fit.lines.map((l) => l.mark), everyElement(LineMark.fits));
      expect(fit.judged, isTrue);
      expect(fit.badge, const FitsBadge());
      expect(fit.badge!.label, 'Passt zu dir');
      expect(fit.passtZuMir, isTrue);
    });

    test('unmapped line with Fruktose', () {
      final fit = _fit([_reis, _drachenfrucht], ['Fruktose']);

      expect(_marks(fit), {
        'Reis': LineMark.fits,
        'Drachenfrucht': LineMark.unknown,
      });
      expect(fit.judged, isFalse);
      expect(fit.badge, isNull);
      expect(fit.passtZuMir, isFalse);

      // A kritisch line still wins the badge.
      final withHonig = _fit([_honig, _drachenfrucht], ['Fruktose']);
      expect(withHonig.judged, isFalse);
      expect(withHonig.badge, const KritischBadge(1));
    });

    test('allergen-only user, unmapped lines', () {
      final ei = testLine('Ei', mapped: false, allergens: {'eier'});
      final fit = _fit([ei, _drachenfrucht], ['Eier']);

      expect(_marks(fit), {
        'Ei': LineMark.kritisch,
        'Drachenfrucht': LineMark.fits,
      });
      expect(fit.kritisch.single.because, ['Eier']);
      expect(fit.judged, isTrue);
    });

    test('not in the table', () {
      final fit = _fit([_butter, _quark], ['Milch']);

      expect(fit.kritischCount, 0);
      expect(fit.badge, const FitsBadge());
    });

    test('rules unknown', () {
      final fit = _fit([_honig, _reis], ['Fruktose'], withRules: false);

      expect(fit.checked, isFalse);
      expect(fit.lines, isEmpty);
      expect(fit.selfCheck, isEmpty);
      expect(fit.judged, isFalse);
      expect(fit.kritischCount, 0);
      expect(fit.badge, isNull);
      expect(fit.passtZuMir, isFalse);
    });

    test('profile unknown', () {
      final fit = _fit([_honig, _reis], null);

      expect(fit.checked, isFalse);
      expect(fit.lines, isEmpty);
      expect(fit.badge, isNull);
      expect(fit.passtZuMir, isFalse);
    });

    test('older recipe', () {
      final older = testRecipe(ingredients: const []);
      expect(older.isLegacy, isTrue);

      final fructose = fitOf(older, rules: _rules, intolerances: ['Fruktose']);
      expect(fructose.lines, isEmpty);
      expect(fructose.judged, isFalse);
      expect(fructose.badge, isNull);
      expect(fructose.passtZuMir, isFalse);

      final none = fitOf(older, rules: _rules, intolerances: const []);
      expect(none.judged, isTrue);
      expect(none.badge, const FitsBadge());
    });

    test('two kritisch lines', () {
      final fit = _fit([_honig, _reis, _quark], ['Fruktose', 'Laktose']);

      expect(fit.kritisch.map((l) => l.line), [_honig, _quark]);
      expect(fit.badge, const KritischBadge(2));
      expect(fit.badge!.label, '2 Zutaten sind für dich kritisch');
    });

    test('an empty table hits nothing', () {
      final fit = fitOf(
        testRecipe(ingredients: [_honig]),
        rules: const IntoleranceRules({}),
        intolerances: ['Fruktose'],
      );

      expect(fit.checked, isTrue);
      expect(fit.badge, const FitsBadge());
    });
  });

  group('badges', () {
    test('compare by value', () {
      final histamin = SelfCheckBadge(List.of(['Histamin']));

      expect(KritischBadge(int.parse('2')), const KritischBadge(2));
      expect(const KritischBadge(2), isNot(const KritischBadge(1)));
      expect(histamin, const SelfCheckBadge(['Histamin']));
      expect(histamin.hashCode, const SelfCheckBadge(['Histamin']).hashCode);
      expect(histamin, isNot(const SelfCheckBadge(['Histamin', 'Sorbit'])));
      expect(const FitsBadge(), isNot(const KritischBadge(0)));
    });
  });

  group('RecipeCopy', () {
    test('joins names in German', () {
      expect(RecipeCopy.kritisch(1), '1 Zutat ist für dich kritisch');
      expect(RecipeCopy.kritisch(3), '3 Zutaten sind für dich kritisch');
      expect(
        RecipeCopy.selfCheck(['Histamin']),
        'Histamin bitte selbst prüfen',
      );
      expect(
        RecipeCopy.because(['Gluten', 'Weizen']),
        'wegen Gluten und Weizen',
      );
      expect(
        RecipeCopy.adaptHint(['Honig', 'Zwiebel', 'Knoblauch']),
        'Ich tausche Honig, Zwiebel und Knoblauch und schreibe die Schritte '
        'passend um.',
      );
      expect(
        RecipeCopy.selfCheckFilter(['Histamin']),
        'Histamin kann ich nicht prüfen, bitte schau da selbst.',
      );
      expect(RecipeCopy.fits, 'Passt zu dir');
      expect(RecipeCopy.kritischSuffix, '— für dich kritisch');
      expect(RecipeCopy.notInCatalog, 'nicht im Katalog');
    });
  });
}
