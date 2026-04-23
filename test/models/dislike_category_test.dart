import 'package:belly_buddy/models/dislike_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DislikeCategory', () {
    test('dbValue round-trips via fromDbValue', () {
      for (final c in DislikeCategory.values) {
        expect(DislikeCategory.fromDbValue(c.dbValue), c);
      }
    });

    test('fromDbValue returns null for unknown strings', () {
      expect(DislikeCategory.fromDbValue('nonsense'), isNull);
      expect(DislikeCategory.fromDbValue(null), isNull);
      expect(DislikeCategory.fromDbValue(''), isNull);
    });

    test('label is German and non-empty', () {
      for (final c in DislikeCategory.values) {
        expect(c.label, isNotEmpty);
      }
      expect(DislikeCategory.notRelevant.label, 'Nicht relevant');
      expect(
        DislikeCategory.dontLikeIngredient.label,
        'Zutat gefällt mir nicht',
      );
      expect(DislikeCategory.dontLikeRecipe.label, 'Rezept gefällt mir nicht');
      expect(DislikeCategory.tooComplicated.label, 'Zu kompliziert');
      expect(DislikeCategory.other.label, 'Anderer Grund');
    });

    test('dbValue strings match the backend contract', () {
      expect(DislikeCategory.notRelevant.dbValue, 'not_relevant');
      expect(
        DislikeCategory.dontLikeIngredient.dbValue,
        'dont_like_ingredient',
      );
      expect(DislikeCategory.dontLikeRecipe.dbValue, 'dont_like_recipe');
      expect(DislikeCategory.tooComplicated.dbValue, 'too_complicated');
      expect(DislikeCategory.other.dbValue, 'other');
    });
  });
}
