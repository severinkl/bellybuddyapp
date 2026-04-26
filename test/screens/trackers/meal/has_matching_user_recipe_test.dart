import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('hasMatchingUserRecipe', () {
    test('returns false when title is empty or whitespace-only', () {
      final recipes = [testUserRecipe(title: 'Curry mit Reis')];
      expect(hasMatchingUserRecipe('', recipes), isFalse);
      expect(hasMatchingUserRecipe('   ', recipes), isFalse);
    });

    test('returns false when recipes is still loading (null)', () {
      expect(hasMatchingUserRecipe('Curry mit Reis', null), isFalse);
    });

    test(
      'returns true when a recipe title matches case-insensitively + trim-insensitively',
      () {
        final recipes = [
          testUserRecipe(id: 'a', title: 'Curry mit Reis'),
          testUserRecipe(id: 'b', title: 'Pasta'),
        ];
        expect(hasMatchingUserRecipe('Curry mit Reis', recipes), isTrue);
        expect(hasMatchingUserRecipe('curry mit reis', recipes), isTrue);
        expect(hasMatchingUserRecipe('  Curry mit Reis  ', recipes), isTrue);
      },
    );

    test('returns false when no recipe title matches', () {
      final recipes = [testUserRecipe(title: 'Curry mit Reis')];
      expect(hasMatchingUserRecipe('Pasta', recipes), isFalse);
    });

    test('returns false when recipes is empty', () {
      expect(hasMatchingUserRecipe('Curry mit Reis', const []), isFalse);
    });
  });
}
