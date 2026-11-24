import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/intolerance_rules.dart';

import '../helpers/fixtures.dart';

void main() {
  group('IntoleranceRules.parse', () {
    test('reads the published table', () {
      final rules = IntoleranceRules.parse(kTestIntoleranceRulesJson)!;

      expect(rules.byName, hasLength(15));
      expect(rules['Laktose']!.fodmaps, {'lactose'});
      expect(rules['Laktose']!.allergens, isEmpty);
      expect(rules['Gluten']!.allergens, {'gluten'});
      expect(rules['Gluten']!.fodmaps, isEmpty);
      expect(rules['Weizen']!.fodmaps, {'fructans'});
      expect(rules['Weizen']!.allergens, {'weizen'});
      expect(rules['Histamin']!.judgeable, isFalse);
      expect(rules['Laktose']!.judgeable, isTrue);
      expect(rules['FODMAPs']!.fodmaps.length, 6);
      expect(rules['Milch']!.allergens, {'milch'});
      expect(rules['Milch']!.fodmaps, isEmpty);
      expect(rules['Erdnuss']!.allergens, {'erdnuss'});
      expect(rules['Erdnuss']!.fodmaps, isEmpty);
    });

    test('an allergen key the app has never seen is kept as it is', () {
      final rules = IntoleranceRules.parse(
        '{"Sesam": {"fodmaps": [], "allergens": ["sesam"], "judgeable": true}}',
      )!;

      expect(rules['Sesam']!.allergens, {'sesam'});
    });

    test('a profile value missing from the table has no rule', () {
      expect(testIntoleranceRules()['Kohl'], isNull);
    });

    test('anything but a JSON object is null', () {
      expect(IntoleranceRules.parse('nope'), isNull);
      expect(IntoleranceRules.parse('[1]'), isNull);
    });

    test('skips non-object entries and unknown FODMAP keys', () {
      final rules = IntoleranceRules.parse(
        '{"X": 3, "Laktose": {"fodmaps": ["lactose", "kohl"]}}',
      )!;

      expect(rules['X'], isNull);
      expect(rules.byName.keys, ['Laktose']);
      expect(rules['Laktose']!.fodmaps, {'lactose'});
      expect(rules['Laktose']!.allergens, isEmpty);
      expect(rules['Laktose']!.judgeable, isTrue);
    });
  });
}
