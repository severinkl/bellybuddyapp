import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/intolerance_rules.dart';

import '../helpers/fixtures.dart';

void main() {
  group('IntoleranceRules.parse', () {
    test('reads the published table', () {
      final rules = IntoleranceRules.parse(kTestIntoleranceRulesJson)!;

      expect(rules.byName, hasLength(13));
      expect(rules['Laktose']!.fodmaps, {'lactose'});
      expect(rules['Laktose']!.allergens, isEmpty);
      expect(rules['Gluten']!.allergens, {'gluten'});
      expect(rules['Gluten']!.fodmaps, isEmpty);
      expect(rules['Weizen']!.fodmaps, {'fructans'});
      expect(rules['Weizen']!.allergens, {'weizen'});
      expect(rules['Histamin']!.judgeable, isFalse);
      expect(rules['Laktose']!.judgeable, isTrue);
      expect(rules['FODMAPs']!.fodmaps.length, 6);
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
