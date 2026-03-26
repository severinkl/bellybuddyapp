// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('RecipesScreen', () {
    testWidgets('renders Rezepte app bar title', (tester) async {
      await tester.pumpWithProviders(const RecipesScreen());
      await tester.pump();

      expect(find.text('Rezepte'), findsOneWidget);
    });

    testWidgets('renders Rezepte kommen bald placeholder', (tester) async {
      await tester.pumpWithProviders(const RecipesScreen());
      await tester.pump();

      expect(find.text('Rezepte kommen bald!'), findsOneWidget);
    });

    testWidgets('renders informational subtitle text', (tester) async {
      await tester.pumpWithProviders(const RecipesScreen());
      await tester.pump();

      expect(find.textContaining('Wir arbeiten gerade'), findsOneWidget);
    });
  });
}
