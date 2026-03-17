import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/user_profile.dart';

void main() {
  group('UserProfile.isComplete', () {
    test('true when all 5 fields non-null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        height: 180,
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isTrue);
    });

    test('false when birthYear is null', () {
      const profile = UserProfile(
        gender: 'männlich',
        height: 180,
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when gender is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        height: 180,
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when height is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when weight is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        height: 180,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when diet is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        height: 180,
        weight: 75,
      );
      expect(profile.isComplete, isFalse);
    });

    test('false with default constructor (all null)', () {
      const profile = UserProfile();
      expect(profile.isComplete, isFalse);
    });
  });
}
