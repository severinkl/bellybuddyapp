import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/user_recipe.dart';

void main() {
  group('UserRecipe', () {
    test('deserializes from Supabase JSON', () {
      final json = {
        'id': 'rec-1',
        'user_id': 'user-1',
        'title': 'Curry mit Reis',
        'ingredients': ['Reis', 'Curry'],
        'image_url': 'https://example.com/img.jpg',
        'created_at': '2026-04-24T10:00:00Z',
        'updated_at': '2026-04-24T10:00:00Z',
      };
      final r = UserRecipe.fromJson(json);
      expect(r.id, 'rec-1');
      expect(r.userId, 'user-1');
      expect(r.title, 'Curry mit Reis');
      expect(r.ingredients, ['Reis', 'Curry']);
      expect(r.imageUrl, 'https://example.com/img.jpg');
    });

    test('allows null image_url and empty ingredients', () {
      final r = UserRecipe.fromJson({
        'id': 'rec-2',
        'user_id': 'user-1',
        'title': 'Minimal',
      });
      expect(r.imageUrl, isNull);
      expect(r.ingredients, isEmpty);
    });

    test('reads amounts, steps and origin; null amounts stay null', () {
      final r = UserRecipe.fromJson({
        'id': 'r',
        'user_id': 'u',
        'title': 'T',
        'ingredients': ['Reis', 'Salz'],
        'ingredient_amounts': ['2 EL', null],
        'instructions': ['Kochen'],
        'adapted_from_recipe_id': 'src-1',
      });
      expect(r.amountOf(0), '2 EL');
      expect(r.amountOf(1), isNull);
      expect(r.amountOf(5), isNull);
      expect(r.instructions, ['Kochen']);
      expect(r.isAdapted, isTrue);
    });

    test('a row from before core #11 has no steps, amounts or origin', () {
      final r = UserRecipe.fromJson({
        'id': 'r',
        'user_id': 'u',
        'title': 'T',
        'ingredients': ['Reis'],
      });
      expect(r.instructions, isEmpty);
      expect(r.ingredientAmounts, isNull);
      expect(r.amountOf(0), isNull);
      expect(r.isAdapted, isFalse);
    });

    test('misaligned amounts give no amount', () {
      final r = UserRecipe.fromJson({
        'id': 'r',
        'user_id': 'u',
        'title': 'T',
        'ingredients': ['Reis', 'Salz'],
        'ingredient_amounts': ['2 EL'],
      });
      expect(r.amountOf(0), isNull);
    });

    test('lostSteps: steps sent, none read back', () {
      const kept = UserRecipe(
        id: 'r',
        userId: 'u',
        title: 'T',
        instructions: ['Kochen'],
      );
      const without = UserRecipe(id: 'r', userId: 'u', title: 'T');
      expect(without.lostSteps(const ['Kochen']), isTrue);
      expect(kept.lostSteps(const ['Kochen']), isFalse);
      expect(without.lostSteps(const []), isFalse);
      expect(without.lostSteps(null), isFalse);
    });
  });
}
