import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/recommendation_item.dart';

void main() {
  group('RecommendationItem', () {
    test('fromJson with all fields present', () {
      final item = RecommendationItem.fromJson({
        'type': 'substitute',
        'ingredient': 'Milch',
        'reason': 'Laktose',
        'alternative': 'Hafermilch',
      });
      expect(item.type, 'substitute');
      expect(item.ingredient, 'Milch');
      expect(item.reason, 'Laktose');
      expect(item.alternative, 'Hafermilch');
    });

    test('fromJson with missing fields uses defaults', () {
      final item = RecommendationItem.fromJson(<String, dynamic>{});
      expect(item.type, 'try');
      expect(item.ingredient, '');
      expect(item.reason, '');
      expect(item.alternative, isNull);
    });

    test('fromJson with null alternative', () {
      final item = RecommendationItem.fromJson({
        'type': 'try',
        'ingredient': 'Ingwer',
        'reason': 'Verdauung',
        'alternative': null,
      });
      expect(item.alternative, isNull);
    });

    test('toJson round-trip with alternative', () {
      const item = RecommendationItem(
        type: 'substitute',
        ingredient: 'Weizen',
        reason: 'Gluten',
        alternative: 'Dinkel',
      );
      final json = item.toJson();
      final restored = RecommendationItem.fromJson(json);
      expect(restored.type, item.type);
      expect(restored.ingredient, item.ingredient);
      expect(restored.reason, item.reason);
      expect(restored.alternative, item.alternative);
    });

    test('toJson excludes alternative when null', () {
      const item = RecommendationItem(
        type: 'try',
        ingredient: 'Ingwer',
        reason: 'Hilft',
      );
      final json = item.toJson();
      expect(json.containsKey('alternative'), isFalse);
    });

    test('isSubstitute true when type is substitute', () {
      const item = RecommendationItem(
        type: 'substitute',
        ingredient: 'a',
        reason: 'b',
      );
      expect(item.isSubstitute, isTrue);
      expect(item.isTry, isFalse);
    });

    test('isTry true when type is try', () {
      const item = RecommendationItem(
        type: 'try',
        ingredient: 'a',
        reason: 'b',
      );
      expect(item.isTry, isTrue);
      expect(item.isSubstitute, isFalse);
    });

    test('unknown type is neither substitute nor try', () {
      const item = RecommendationItem(
        type: 'avoid',
        ingredient: 'a',
        reason: 'b',
      );
      expect(item.isSubstitute, isFalse);
      expect(item.isTry, isFalse);
    });
  });
}
