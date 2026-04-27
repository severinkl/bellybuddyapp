import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/feature_card.dart';
import 'package:belly_buddy/screens/recipes/recipes_screen.dart';

import '../test/helpers/fakes.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setNotificationModalShown();
  });

  testWidgets(
    'tapping the Rezepte feature card opens the recipes screen with the empty state',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final rezepteCard = find.widgetWithText(FeatureCard, 'Rezepte');
      expect(rezepteCard, findsOneWidget);

      await tester.ensureVisible(rezepteCard);
      await tester.pumpAndSettle();
      await tester.tap(rezepteCard);
      await tester.pumpAndSettle();

      expect(find.byType(RecipesScreen), findsOneWidget);
      expect(find.text('Noch keine Rezepte'), findsOneWidget);
      expect(find.text('Erstes Rezept erstellen'), findsOneWidget);
    },
  );

  testWidgets(
    'recipes screen lists pre-seeded user recipes from the repository',
    (tester) async {
      final repo = FakeUserRecipeRepository(
        seed: [
          testUserRecipe(id: 'r1', title: 'Curry mit Reis'),
          testUserRecipe(id: 'r2', title: 'Pasta Bolognese'),
        ],
      );

      await tester.pumpWidget(buildTestApp(userRecipeRepo: repo));
      await tester.pumpAndSettle();

      final rezepteCard = find.widgetWithText(FeatureCard, 'Rezepte');
      await tester.ensureVisible(rezepteCard);
      await tester.pumpAndSettle();
      await tester.tap(rezepteCard);
      await tester.pumpAndSettle();

      expect(find.byType(RecipesScreen), findsOneWidget);
      expect(find.text('Curry mit Reis'), findsOneWidget);
      expect(find.text('Pasta Bolognese'), findsOneWidget);
      // Empty-state CTA should NOT be present when the user has recipes.
      expect(find.text('Erstes Rezept erstellen'), findsNothing);
    },
  );
}
