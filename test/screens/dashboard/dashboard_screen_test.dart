// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

List<Override> _overrides() => [
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  currentUserIdProvider.overrideWithValue('test-user'),
];

void main() {
  group('DashboardScreen', () {
    testWidgets('renders feature card Für dich', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Für dich'), findsOneWidget);
    });

    testWidgets('renders feature card Alternativen', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alternativen'), findsOneWidget);
    });

    testWidgets('renders feature card Rezepte', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rezepte'), findsOneWidget);
    });

    testWidgets('renders TrackerCards with Bauchgefühl and Klo', (
      tester,
    ) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bauchgefühl'), findsOneWidget);
      expect(find.text('Klo'), findsOneWidget);
    });

    testWidgets('renders Für dich erstellt section header', (tester) async {
      await tester.pumpWithProviders(
        const DashboardScreen(),
        overrides: _overrides(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Für dich erstellt'), findsOneWidget);
    });
  });
}
