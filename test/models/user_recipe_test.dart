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
  });
}
