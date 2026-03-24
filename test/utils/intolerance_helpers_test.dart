import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/intolerance_helpers.dart';
import 'package:belly_buddy/models/user_profile.dart';

void main() {
  const profile = UserProfile(
    fructoseTriggers: ['Apfel', 'Birne'],
    lactoseTriggers: ['Milch'],
    histaminTriggers: ['Tomate', 'Spinat'],
  );

  group('IntoleranceHelpers.triggersFor', () {
    test('Fruktose returns fructoseTriggers', () {
      expect(IntoleranceHelpers.triggersFor('Fruktose', profile), [
        'Apfel',
        'Birne',
      ]);
    });

    test('Laktose returns lactoseTriggers', () {
      expect(IntoleranceHelpers.triggersFor('Laktose', profile), ['Milch']);
    });

    test('Histamin returns histaminTriggers', () {
      expect(IntoleranceHelpers.triggersFor('Histamin', profile), [
        'Tomate',
        'Spinat',
      ]);
    });

    test('unknown intolerance returns empty list', () {
      expect(IntoleranceHelpers.triggersFor('Unknown', profile), isEmpty);
    });
  });

  group('IntoleranceHelpers.updateTriggers', () {
    test('updates fructose triggers', () {
      final updated = IntoleranceHelpers.updateTriggers('Fruktose', profile, [
        'Mango',
      ]);
      expect(updated.fructoseTriggers, ['Mango']);
      expect(updated.lactoseTriggers, profile.lactoseTriggers);
    });

    test('updates lactose triggers', () {
      final updated = IntoleranceHelpers.updateTriggers('Laktose', profile, [
        'Käse',
        'Joghurt',
      ]);
      expect(updated.lactoseTriggers, ['Käse', 'Joghurt']);
      expect(updated.fructoseTriggers, profile.fructoseTriggers);
    });

    test('updates histamin triggers', () {
      final updated = IntoleranceHelpers.updateTriggers('Histamin', profile, [
        'Wein',
      ]);
      expect(updated.histaminTriggers, ['Wein']);
    });

    test('unknown intolerance returns profile unchanged', () {
      final updated = IntoleranceHelpers.updateTriggers('Unknown', profile, [
        'test',
      ]);
      expect(updated, profile);
    });
  });
}
