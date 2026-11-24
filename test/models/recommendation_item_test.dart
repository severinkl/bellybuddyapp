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

  group('focus and recipe link (core #12)', () {
    const oldKeys = {
      'type': 'substitute',
      'ingredient': 'Zwiebel',
      'reason': 'r',
      'alternative': 'Frühlingszwiebelgrün',
    };

    test('new fields read', () {
      final item = RecommendationItem.fromJson({
        ...oldKeys,
        'focus': true,
        'recipe_id': 'r-1',
        'recipe_title': 'Hirse-Bowl',
      });
      expect(item.focus, isTrue);
      expect(item.recipeId, 'r-1');
      expect(item.recipeTitle, 'Hirse-Bowl');
      expect(item.hasRecipeLink, isTrue);
    });

    test('an old item', () {
      final item = RecommendationItem.fromJson(oldKeys);
      expect(item.focus, isFalse);
      expect(item.recipeId, isNull);
      expect(item.recipeTitle, isNull);
      expect(item.hasRecipeLink, isFalse);
    });

    test('focus "true" (a string) is false', () {
      final item = RecommendationItem.fromJson({...oldKeys, 'focus': 'true'});
      expect(item.focus, isFalse);
    });

    test('blank recipe_id is null', () {
      final item = RecommendationItem.fromJson({
        ...oldKeys,
        'recipe_id': '  ',
        'recipe_title': ' ',
      });
      expect(item.recipeId, isNull);
      expect(item.recipeTitle, isNull);
      expect(item.hasRecipeLink, isFalse);
    });

    test('recipe fields are trimmed', () {
      final item = RecommendationItem.fromJson({
        ...oldKeys,
        'recipe_id': ' r-1 ',
        'recipe_title': ' Hirse-Bowl\n',
      });
      expect(item.recipeId, 'r-1');
      expect(item.recipeTitle, 'Hirse-Bowl');
    });

    test('a try item with recipe_id has no link', () {
      final item = RecommendationItem.fromJson({
        'type': 'try',
        'ingredient': 'Haferflocken',
        'reason': 'r',
        'recipe_id': 'r-1',
      });
      expect(item.recipeId, 'r-1');
      expect(item.hasRecipeLink, isFalse);
    });

    test('toJson: an old item gives exactly the old keys', () {
      expect(RecommendationItem.fromJson(oldKeys).toJson(), oldKeys);
    });

    test('toJson: a new item round-trips', () {
      final json = {
        ...oldKeys,
        'focus': true,
        'recipe_id': 'r-1',
        'recipe_title': 'Hirse-Bowl',
      };
      final restored = RecommendationItem.fromJson(
        RecommendationItem.fromJson(json).toJson(),
      );
      expect(restored.toJson(), json);
      expect(restored.focus, isTrue);
      expect(restored.recipeId, 'r-1');
      expect(restored.recipeTitle, 'Hirse-Bowl');
    });
  });
}
