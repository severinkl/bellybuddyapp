// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('MealTrackerScreen', () {
    testWidgets('renders Neue Mahlzeit title text', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Neue Mahlzeit'), findsOneWidget);
    });

    testWidgets('renders Speichern button', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('renders Getränk tracken button', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.text('Getränk tracken'), findsOneWidget);
    });

    testWidgets('renders edit icon next to title', (tester) async {
      await tester.pumpWithProviders(
        const MealTrackerScreen(),
        overrides: _overrides(),
      );
      await tester.pump();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}
